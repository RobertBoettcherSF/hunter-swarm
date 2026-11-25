-- Maze chase. The eater plays for score. Four ghosts play to keep it low.
-- Web-safe Plain Ada: fixed storage, no heap, no tasks. The host ABI is Swarm.API.

with Interfaces;

package Swarm is

   Width  : constant := 19;
   Height : constant := 21;

   type X_Pos is range 0 .. Width - 1;
   type Y_Pos is range 0 .. Height - 1;

   subtype Ghost_Id is Integer range 1 .. 4;

   -- Host parameter numbers. JS reads the same indexes.
   Param_Count : constant := 9;
   subtype Param_Index is Integer range 1 .. Param_Count;
   Danger_Radius : constant Param_Index := 1;
   Power_Seek    : constant Param_Index := 2;
   Threat_Range  : constant Param_Index := 3;
   Hunt_Range    : constant Param_Index := 4;
   Cutoff_Lead   : constant Param_Index := 5;
   Role_Interval : constant Param_Index := 6;
   Fright_Ticks  : constant Param_Index := 7;
   Starve_Ticks  : constant Param_Index := 8;
   Ghost_Stride  : constant Param_Index := 9;

   -- Pos values are the numbers the page shows. Do not reorder them.
   type Outcome_Kind is (Running, Won, Lost, Timed_Out);
   type Decision_Code is
     (None, Seek_Pellet, Seek_Power, Flee, Hunt,
      Chase, Cutoff, Cover, Ghost_Flee, Return_Home);
   type Ghost_Mode is (G_Chase, G_Cutoff, G_Cover, G_Flee, G_Return);

   type Game is limited private;

   procedure Set_Param
     (G : in out Game; Index : Integer; Value : Integer; OK : out Boolean)
   with Post => (if OK then Param (G, Index) = Value);

   -- Grid 0 is the fixed hand-made maze. Any other grid seed builds a maze.
   -- Eater seed picks the opening cell and the eater's tie-break.
   -- Ghost seed picks the ghost roles. The ghost rules do not read the eater seed.
   procedure Start
     (G : in out Game;
      Grid_Seed, Eater_Seed, Ghost_Seed : Interfaces.Unsigned_32)
   with Post =>
     Started (G) and then Outcome (G) = Running
     and then Pellets_Left (G) > 0 and then Lives (G) = 5
     and then Tick_Count (G) = 0;

   procedure Tick (G : in out Game)
   with Pre => Started (G),
        Post => Started (G);

   function Param (G : Game; Index : Integer) return Integer;
   function Param_Min (Index : Integer) return Integer;
   function Param_Max (Index : Integer) return Integer;

   function Started (G : Game) return Boolean;
   function Outcome (G : Game) return Outcome_Kind;
   function Score (G : Game) return Natural;
   function Lives (G : Game) return Natural;
   function Deaths (G : Game) return Natural;
   function Catches (G : Game) return Natural;
   function Tick_Count (G : Game) return Natural;
   function Pellets_Left (G : Game) return Natural;
   function Power_Left (G : Game) return Natural;
   function State_Hash (G : Game) return Interfaces.Unsigned_32;

   -- 0 wall, 1 empty floor, 2 pellet, 3 power. Out of range is 0.
   function Tile_Code (G : Game; X, Y : Integer) return Natural;

   function Eater_X (G : Game) return Integer;
   function Eater_Y (G : Game) return Integer;
   function Eater_DX (G : Game) return Integer;
   function Eater_DY (G : Game) return Integer;
   function Ghost_X (G : Game; Id : Ghost_Id) return Integer;
   function Ghost_Y (G : Game; Id : Ghost_Id) return Integer;
   function Ghost_Mode_Code (G : Game; Id : Ghost_Id) return Natural;
   -- Actor 0 is the eater. Actors 1 .. 4 are the ghosts.
   function Decision_Of (G : Game; Actor : Natural) return Decision_Code;

   -- The single game the browser calls. Native smoke uses its own Game.
   function Host_Started return Boolean;

private

   type Event_Code is
     (Game_Start, Pellet_Eaten, Power_Eaten, Death, Catch,
      Fright_End, Win, Lose, Timeout);

   Max_Decisions : constant := 1200;
   Max_Events    : constant := 600;

   -- Knobs that are not host parameters. The report copies these out.
   Pellet_Points       : constant := 10;
   Power_Points        : constant := 50;
   Initial_Lives       : constant := 5;
   Respawn_Pause_Ticks : constant := 12;
   Tick_Cap            : constant := 4000;
   Log_Gap             : constant := 25;
   Score_Limit         : constant := 10_000_000;
   Lookahead           : constant := 4;
   Commit_Ticks        : constant := 6;
   Max_Deaths          : constant := 8;

   type Tile_Kind is (Wall, Floor);

   type Tile is record
      Kind   : Tile_Kind := Wall;
      Pellet : Boolean := False;
      Power  : Boolean := False;
   end record;

   type Choice is record
      Code : Decision_Code := None;
      X    : Integer := 0;
      Y    : Integer := 0;
      Tick : Natural := 0;
   end record;

   type Ghost is record
      X          : X_Pos := 0;
      Y          : Y_Pos := 0;
      DX, DY     : Integer := 0;
      Mode       : Ghost_Mode := G_Chase;
      Home_X     : X_Pos := 0;
      Home_Y     : Y_Pos := 0;
      Last       : Choice := (others => <>);
   end record;

   type Decision is record
      Tick  : Natural := 0;
      Actor : Natural := 0;
      Code  : Decision_Code := None;
      X     : Integer := 0;
      Y     : Integer := 0;
   end record;

   type Event is record
      Tick : Natural := 0;
      Code : Event_Code := Game_Start;
      A    : Integer := 0;
      B    : Integer := 0;
   end record;

   type Death_Note is record
      Tick     : Natural := 0;
      Killer   : Natural := 0;
      Near     : Natural := 0;
      Exits    : Natural := 0;
      Choice   : Decision_Code := None;
      Dist_Ago : Natural := 0;
   end record;
   type Death_List is array (1 .. Max_Deaths) of Death_Note;
   type Ago_Array is array (Ghost_Id, 1 .. Lookahead) of Natural;

   type Param_Array is array (Param_Index) of Integer;
   type Ghost_Array is array (Ghost_Id) of Ghost;
   type Corner_Array is array (Ghost_Id) of Integer;
   type Cover_Array is array (1 .. 2) of Integer;
   type Decision_Array is array (1 .. Max_Decisions) of Decision;
   type Event_Array is array (1 .. Max_Events) of Event;
   type Tile_Array is array (X_Pos, Y_Pos) of Tile;

   type Game is limited record
      Defaults_Ready : Boolean := False;
      Started        : Boolean := False;
      Params         : Param_Array := [others => 0];
      Grid_Seed      : Interfaces.Unsigned_32 := 0;
      Eater_Seed     : Interfaces.Unsigned_32 := 0;
      Ghost_Seed     : Interfaces.Unsigned_32 := 0;
      Bias           : Natural := 0;
      Eater_Bias     : Natural := 0;
      Commit_Left    : Natural := 0;
      Commit_X       : Integer := 0;
      Commit_Y       : Integer := 0;
      Commit_Code    : Decision_Code := None;
      Death_Count    : Natural := 0;
      Why            : Death_List := [others => <>];
      Ago            : Ago_Array := [others => [others => 0]];
      Tick           : Natural := 0;
      Score          : Natural := 0;
      Lives          : Natural := 0;
      Deaths         : Natural := 0;
      Catches        : Natural := 0;
      Pellets        : Natural := 0;
      Power_Left     : Natural := 0;
      Chain          : Natural := 0;
      Ticks_Since_Eat : Natural := 0;
      Ate            : Boolean := False;
      Respawn_Pause  : Natural := 0;
      Outcome        : Outcome_Kind := Running;
      E_X            : X_Pos := 0;
      E_Y            : Y_Pos := 0;
      E_DX, E_DY     : Integer := 0;
      Spawn_X        : X_Pos := 0;
      Spawn_Y        : Y_Pos := 0;
      E_Last         : Choice := (others => <>);
      Ghosts         : Ghost_Array := [others => <>];
      Flee_X         : Corner_Array := [others => 0];
      Flee_Y         : Corner_Array := [others => 0];
      Cover_Q        : Cover_Array := [others => 1];
      Role_Timer     : Natural := 0;
      Dec_Next       : Natural := 1;
      Dec_Count      : Natural := 0;
      Dec_Dropped    : Natural := 0;
      Decs           : Decision_Array := [others => <>];
      Ev_Next        : Natural := 1;
      Ev_Count       : Natural := 0;
      Ev_Dropped     : Natural := 0;
      Evs            : Event_Array := [others => <>];
      Tiles          : Tile_Array := [others => [others => <>]];
      Error_Used     : Boolean := False;
      Error_Line     : Natural := 0;
   end record;

   The_Game : Game;

end Swarm;
