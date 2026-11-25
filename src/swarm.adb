package body Swarm is

   use type Interfaces.Unsigned_32;

   subtype Row is String (1 .. Width);
   type Maze_Rows is array (1 .. Height) of Row;

   -- Original layout: 19 by 21, asymmetric, no holding pen.
   Maze : constant Maze_Rows :=
     [1  => "###################",
      2  => "#o....#..........o#",
      3  => "#.###.#.#.###.#.###",
      4  => "#.................#",
      5  => "#.#.#.#.#.#.###.#.#",
      6  => "#...#.#.#.#.....#.#",
      7  => "#.#.#.###.###.#.###",
      8  => "#.#...........#...#",
      9  => "#.###.#.#####.#.#.#",
      10 => "#.#.......#...#...#",
      11 => "###.###.###.###.#.#",
      12 => "#...#.....#...#...#",
      13 => "#.#.#####.#.#.#.#.#",
      14 => "#.....#.#...#.#.#.#",
      15 => "###.#.#.###.###.#.#",
      16 => "#...#.#.........#o#",
      17 => "###.###.#######.#.#",
      18 => "#.#...#.........#.#",
      19 => "#.#.#.#######.#.#.#",
      20 => "#o............#...#",
      21 => "###################"];

   Unseen : constant Natural := 10_000;

   type Step is record
      DX, DY : Integer;
   end record;
   type Step_List is array (0 .. 3) of Step;
   Dirs : constant Step_List :=
     [0 => (DX => 0, DY => -1),
      1 => (DX => 1, DY => 0),
      2 => (DX => 0, DY => 1),
      3 => (DX => -1, DY => 0)];

   type Seek_Kind is (Seek_Cell, Seek_Food, Seek_Power, Seek_Fright);
   type Dist_Map is array (X_Pos, Y_Pos) of Natural;
   type Parent_Map is array (X_Pos, Y_Pos) of Integer;

   function Default_Param (Index : Param_Index) return Integer is
   begin
      case Index is
         when Danger_Radius => return 3;
         when Power_Seek    => return 12;
         when Threat_Range  => return 6;
         when Hunt_Range    => return 10;
         when Cutoff_Lead   => return 4;
         when Role_Interval => return 16;
         when Fright_Ticks  => return 30;
         when Starve_Ticks  => return 18;
         when Ghost_Stride  => return 2;
      end case;
   end Default_Param;

   function Min_Param (Index : Param_Index) return Integer is
   begin
      case Index is
         when Danger_Radius => return 1;
         when Power_Seek    => return 1;
         when Threat_Range  => return 1;
         when Hunt_Range    => return 1;
         when Cutoff_Lead   => return 1;
         when Role_Interval => return 1;
         when Fright_Ticks  => return 4;
         when Starve_Ticks  => return 1;
         when Ghost_Stride  => return 1;
      end case;
   end Min_Param;

   function Max_Param (Index : Param_Index) return Integer is
   begin
      case Index is
         when Danger_Radius => return 20;
         when Power_Seek    => return 40;
         when Threat_Range  => return 30;
         when Hunt_Range    => return 40;
         when Cutoff_Lead   => return 12;
         when Role_Interval => return 80;
         when Fright_Ticks  => return 160;
         when Starve_Ticks  => return 200;
         when Ghost_Stride  => return 4;
      end case;
   end Max_Param;

   procedure Ensure (G : in out Game) is
   begin
      if G.Defaults_Ready then
         return;
      end if;
      for I in Param_Index loop
         G.Params (I) := Default_Param (I);
      end loop;
      G.Defaults_Ready := True;
   end Ensure;

   function Open (G : Game; X, Y : Integer) return Boolean is
   begin
      if X < Integer (X_Pos'First) or else X > Integer (X_Pos'Last) then
         return False;
      end if;
      if Y < Integer (Y_Pos'First) or else Y > Integer (Y_Pos'Last) then
         return False;
      end if;
      return G.Tiles (X_Pos (X), Y_Pos (Y)).Kind = Floor;
   end Open;

   function Quadrant (X, Y : Integer) return Integer is
   begin
      if Y < Height / 2 then
         if X < Width / 2 then
            return 1;
         else
            return 2;
         end if;
      elsif X < Width / 2 then
         return 3;
      else
         return 4;
      end if;
   end Quadrant;

   function Catch_Points (Chain : Natural) return Natural is
   begin
      case Chain is
         when 0 => return 200;
         when 1 => return 400;
         when 2 => return 800;
         when others => return 1600;
      end case;
   end Catch_Points;

   function Role (G : Game; Id : Ghost_Id) return Ghost_Mode is
      Shifted : constant Integer := ((Id - 1 + G.Bias) mod 4) + 1;
   begin
      case Shifted is
         when 1 => return G_Chase;
         when 2 => return G_Cutoff;
         when 3 => return G_Cover;
         when others => return G_Cover;
      end case;
   end Role;

   function Cover_Slot (G : Game; Id : Ghost_Id) return Integer is
      Shifted : constant Integer := ((Id - 1 + G.Bias) mod 4) + 1;
   begin
      if Shifted = 4 then
         return 2;
      else
         return 1;
      end if;
   end Cover_Slot;

   procedure Push_Decision
     (G : in out Game; Actor : Natural; Code : Decision_Code; X, Y : Integer)
   is
   begin
      pragma Assert (G.Dec_Next in 1 .. Max_Decisions);
      G.Decs (G.Dec_Next) :=
        (Tick => G.Tick, Actor => Actor, Code => Code, X => X, Y => Y);
      if G.Dec_Next = Max_Decisions then
         G.Dec_Next := 1;
      else
         G.Dec_Next := G.Dec_Next + 1;
      end if;
      if G.Dec_Count < Max_Decisions then
         G.Dec_Count := G.Dec_Count + 1;
      else
         G.Dec_Dropped := G.Dec_Dropped + 1;
      end if;
   end Push_Decision;

   procedure Push_Event
     (G : in out Game; Code : Event_Code; A, B : Integer)
   is
   begin
      pragma Assert (G.Ev_Next in 1 .. Max_Events);
      G.Evs (G.Ev_Next) := (Tick => G.Tick, Code => Code, A => A, B => B);
      if G.Ev_Next = Max_Events then
         G.Ev_Next := 1;
      else
         G.Ev_Next := G.Ev_Next + 1;
      end if;
      if G.Ev_Count < Max_Events then
         G.Ev_Count := G.Ev_Count + 1;
      else
         G.Ev_Dropped := G.Ev_Dropped + 1;
      end if;
   end Push_Event;

   procedure Note_Choice
     (G : in out Game; Last : in out Choice; Actor : Natural;
      Code : Decision_Code; X, Y : Integer)
   is
      Due : Boolean;
   begin
      Due := Last.Code /= Code or else Last.Tick = 0
        or else G.Tick >= Last.Tick + Log_Gap;
      Last.Code := Code;
      Last.X := X;
      Last.Y := Y;
      if Due then
         Last.Tick := G.Tick;
         Push_Decision (G, Actor, Code, X, Y);
      end if;
   end Note_Choice;

   function Is_Goal
     (G : Game; Mode : Seek_Kind; X : X_Pos; Y : Y_Pos; TX, TY : Integer)
      return Boolean
   is
   begin
      case Mode is
         when Seek_Cell =>
            return Integer (X) = TX and then Integer (Y) = TY;
         when Seek_Food =>
            return G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power;
         when Seek_Power =>
            return G.Tiles (X, Y).Power;
         when Seek_Fright =>
            for Id in Ghost_Id loop
               if G.Ghosts (Id).Mode = G_Flee
                 and then G.Ghosts (Id).X = X
                 and then G.Ghosts (Id).Y = Y
               then
                  return True;
               end if;
            end loop;
            return False;
      end case;
   end Is_Goal;

   procedure Hostile_Map (G : Game; D : out Dist_Map; Any : out Boolean);

   function Ghost_Stands (G : Game; X, Y : Integer) return Boolean is
   begin
      for Id in Ghost_Id loop
         if G.Ghosts (Id).Mode /= G_Return
           and then G.Ghosts (Id).Mode /= G_Flee
           and then Integer (G.Ghosts (Id).X) = X
           and then Integer (G.Ghosts (Id).Y) = Y
         then
            return True;
         end if;
      end loop;
      return False;
   end Ghost_Stands;

   -- On a tick the ghosts move after the eater, any cell next to a hostile
   -- ghost is a cell that ghost can step onto once the eater has moved.
   function Lethal_Cell (G : Game; X, Y : Integer) return Boolean is
   begin
      if Ghost_Stands (G, X, Y) then
         return True;
      end if;
      if G.Power_Left = 0 and then G.Params (Ghost_Stride) >= 1
        and then G.Tick mod G.Params (Ghost_Stride) = 0
      then
         for Id in Ghost_Id loop
            if G.Ghosts (Id).Mode /= G_Return
              and then G.Ghosts (Id).Mode /= G_Flee
              and then abs (Integer (G.Ghosts (Id).X) - X)
                + abs (Integer (G.Ghosts (Id).Y) - Y) = 1
            then
               return True;
            end if;
         end loop;
      end if;
      return False;
   end Lethal_Cell;

   function Power_At (G : Game; X, Y : Integer) return Boolean is
   begin
      if not Open (G, X, Y) then
         return False;
      end if;
      return G.Tiles (X_Pos (X), Y_Pos (Y)).Power;
   end Power_At;

   function Cell_Exits (G : Game; X : X_Pos; Y : Y_Pos) return Natural is
      N : Natural := 0;
   begin
      for K in 0 .. 3 loop
         if Open (G, Integer (X) + Dirs (K).DX, Integer (Y) + Dirs (K).DY) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Cell_Exits;

   procedure Seek_From
     (G : Game; SX, SY : Integer; Mode : Seek_Kind; TX, TY : Integer;
      Order : Natural; Safe, Skip_Pocket, Block_Ghosts, Avoid_Power : Boolean;
      Found : out Boolean; GX, GY, Dist, Step_X, Step_Y : out Integer)
   is
      D  : Dist_Map;
      PX : Parent_Map;
      PY : Parent_Map;
      HD : Dist_Map;
      QX : array (0 .. Width * Height - 1) of X_Pos;
      QY : array (0 .. Width * Height - 1) of Y_Pos;
      Head, Tail : Natural := 0;
      X0 : X_Pos;
      Y0 : Y_Pos;
      Ghosts_Near : Boolean := False;
   begin
      Found := False;
      GX := SX;
      GY := SY;
      Dist := 0;
      Step_X := SX;
      Step_Y := SY;
      if not Open (G, SX, SY) then
         return;
      end if;
      X0 := X_Pos (SX);
      Y0 := Y_Pos (SY);
      for Y in Y_Pos loop
         for X in X_Pos loop
            D (X, Y) := Unseen;
            PX (X, Y) := -1;
            PY (X, Y) := -1;
         end loop;
      end loop;
      D (X0, Y0) := 0;
      QX (0) := X0;
      QY (0) := Y0;
      Tail := 1;
      if Safe then
         Hostile_Map (G, HD, Ghosts_Near);
      end if;
      while Head /= Tail loop
         declare
            CX : constant X_Pos := QX (Head);
            CY : constant Y_Pos := QY (Head);
            Unsafe : Boolean := False;
         begin
            Head := Head + 1;
            if Safe and then Ghosts_Near and then HD (CX, CY) /= Unseen
              and then HD (CX, CY) <= D (CX, CY)
              and then D (CX, CY) > 0
            then
               Unsafe := True;
            end if;
            if Is_Goal (G, Mode, CX, CY, TX, TY) and then not Unsafe
              and then not (Skip_Pocket and then Mode = Seek_Food
                            and then Cell_Exits (G, CX, CY) < 2)
            then
               Found := True;
               GX := Integer (CX);
               GY := Integer (CY);
               Dist := D (CX, CY);
               if Dist = 0 then
                  Step_X := GX;
                  Step_Y := GY;
               else
                  declare
                     WX : Integer := Integer (CX);
                     WY : Integer := Integer (CY);
                     Guard : Natural := 0;
                  begin
                     loop
                        declare
                           Parent_X : constant Integer :=
                             PX (X_Pos (WX), Y_Pos (WY));
                           Parent_Y : constant Integer :=
                             PY (X_Pos (WX), Y_Pos (WY));
                        begin
                           exit when Parent_X = Integer (X0)
                             and then Parent_Y = Integer (Y0);
                           pragma Assert (Parent_X >= 0);
                           WX := Parent_X;
                           WY := Parent_Y;
                        end;
                        Guard := Guard + 1;
                        pragma Assert (Guard < Width * Height);
                     end loop;
                     Step_X := WX;
                     Step_Y := WY;
                  end;
               end if;
               return;
            end if;
            for K in 0 .. 3 loop
               declare
                  Dir : constant Step := Dirs ((K + Order) mod 4);
                  NX  : constant Integer := Integer (CX) + Dir.DX;
                  NY  : constant Integer := Integer (CY) + Dir.DY;
               begin
                  if Open (G, NX, NY)
                    and then D (X_Pos (NX), Y_Pos (NY)) = Unseen
                  then
                     declare
                        Next_D : constant Natural := D (CX, CY) + 1;
                        Blocked : Boolean := False;
                     begin
                        pragma Assert (D (CX, CY) < Unseen - 1);
                        if Safe and then Ghosts_Near
                          and then HD (X_Pos (NX), Y_Pos (NY)) /= Unseen
                          and then HD (X_Pos (NX), Y_Pos (NY)) <= Next_D
                        then
                           Blocked := True;
                        end if;
                        if Block_Ghosts and then Lethal_Cell (G, NX, NY) then
                           Blocked := True;
                        end if;
                        if Avoid_Power and then Power_At (G, NX, NY) then
                           Blocked := True;
                        end if;
                        if not Blocked then
                           pragma Assert (Tail < QX'Length);
                           D (X_Pos (NX), Y_Pos (NY)) := Next_D;
                           PX (X_Pos (NX), Y_Pos (NY)) := Integer (CX);
                           PY (X_Pos (NX), Y_Pos (NY)) := Integer (CY);
                           QX (Tail) := X_Pos (NX);
                           QY (Tail) := Y_Pos (NY);
                           Tail := Tail + 1;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Seek_From;

   procedure Hostile_Map (G : Game; D : out Dist_Map; Any : out Boolean) is
      QX : array (0 .. Width * Height - 1) of X_Pos;
      QY : array (0 .. Width * Height - 1) of Y_Pos;
      Head, Tail : Natural := 0;
   begin
      Any := False;
      for Y in Y_Pos loop
         for X in X_Pos loop
            D (X, Y) := Unseen;
         end loop;
      end loop;
      if G.Power_Left /= 0 then
         return;
      end if;
      for Id in Ghost_Id loop
         if G.Ghosts (Id).Mode /= G_Return
           and then G.Ghosts (Id).Mode /= G_Flee
           and then D (G.Ghosts (Id).X, G.Ghosts (Id).Y) = Unseen
         then
            Any := True;
            D (G.Ghosts (Id).X, G.Ghosts (Id).Y) := 0;
            pragma Assert (Tail < QX'Length);
            QX (Tail) := G.Ghosts (Id).X;
            QY (Tail) := G.Ghosts (Id).Y;
            Tail := Tail + 1;
         end if;
      end loop;
      while Head /= Tail loop
         declare
            CX : constant X_Pos := QX (Head);
            CY : constant Y_Pos := QY (Head);
         begin
            Head := Head + 1;
            for K in 0 .. 3 loop
               declare
                  Dir : constant Step := Dirs (K);
                  NX  : constant Integer := Integer (CX) + Dir.DX;
                  NY  : constant Integer := Integer (CY) + Dir.DY;
               begin
                  if Open (G, NX, NY)
                    and then D (X_Pos (NX), Y_Pos (NY)) = Unseen
                  then
                     pragma Assert (D (CX, CY) < Unseen - 1);
                     pragma Assert (Tail < QX'Length);
                     D (X_Pos (NX), Y_Pos (NY)) := D (CX, CY) + 1;
                     QX (Tail) := X_Pos (NX);
                     QY (Tail) := Y_Pos (NY);
                     Tail := Tail + 1;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Hostile_Map;

   procedure Assign_Cover (G : in out Game) is
      Count : array (1 .. 4) of Natural := [others => 0];
      Best : Integer := 1;
      Second : Integer := 2;

      function Better (A, B : Integer) return Boolean is
         KA : constant Integer := (A - 1 + G.Bias) mod 4;
         KB : constant Integer := (B - 1 + G.Bias) mod 4;
      begin
         if Count (A) /= Count (B) then
            return Count (A) > Count (B);
         end if;
         if KA /= KB then
            return KA > KB;
         end if;
         return A > B;
      end Better;
   begin
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power then
               declare
                  Q : constant Integer := Quadrant (Integer (X), Integer (Y));
               begin
                  Count (Q) := Count (Q) + 1;
               end;
            end if;
         end loop;
      end loop;
      for Q in 2 .. 4 loop
         if Better (Q, Best) then
            Best := Q;
         end if;
      end loop;
      if Best = 1 then
         Second := 2;
      else
         Second := 1;
      end if;
      for Q in 1 .. 4 loop
         if Q /= Best and then Better (Q, Second) then
            Second := Q;
         end if;
      end loop;
      G.Cover_Q (1) := Best;
      G.Cover_Q (2) := Second;
   end Assign_Cover;

   procedure Assign_Flee (G : in out Game) is
   begin
      -- Each ghost takes a different compass direction away from the eater.
      for Id in Ghost_Id loop
         declare
            Dir : constant Natural := (Id - 1) mod 4;
            Found : Boolean := False;
            Best : Integer := Integer'First;
            Best_X : Integer := Integer (G.E_X);
            Best_Y : Integer := Integer (G.E_Y);
         begin
            for Y in Y_Pos loop
               for X in X_Pos loop
                  if G.Tiles (X, Y).Kind = Floor then
                     declare
                        Score : Integer;
                        Taken : Boolean := False;
                     begin
                        case Dir is
                           when 0 =>
                              Score := Integer (G.E_Y) - Integer (Y);
                           when 1 =>
                              Score := Integer (X) - Integer (G.E_X);
                           when 2 =>
                              Score := Integer (Y) - Integer (G.E_Y);
                           when others =>
                              Score := Integer (G.E_X) - Integer (X);
                        end case;
                        for Prev in 1 .. Id - 1 loop
                           if G.Flee_X (Prev) = Integer (X)
                             and then G.Flee_Y (Prev) = Integer (Y)
                           then
                              Taken := True;
                           end if;
                        end loop;
                        if not Taken and then (not Found or else Score > Best) then
                           Found := True;
                           Best := Score;
                           Best_X := Integer (X);
                           Best_Y := Integer (Y);
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            G.Flee_X (Id) := Best_X;
            G.Flee_Y (Id) := Best_Y;
         end;
      end loop;
   end Assign_Flee;

   procedure Cover_Target
     (G : Game; Id : Ghost_Id; TX, TY : out Integer)
   is
      Quad : constant Integer := G.Cover_Q (Cover_Slot (G, Id));
      Best : Natural := Natural'Last;
      Found : Boolean := False;
      FX : Integer := Integer (G.E_X);
      FY : Integer := Integer (G.E_Y);
   begin
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Kind = Floor
              and then Quadrant (Integer (X), Integer (Y)) = Quad
            then
               declare
                  Food : constant Boolean :=
                    G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power;
                  D : constant Natural :=
                    abs (Integer (X) - Integer (G.Ghosts (Id).X))
                    + abs (Integer (Y) - Integer (G.Ghosts (Id).Y));
               begin
                  if Food and then (not Found or else D < Best) then
                     Found := True;
                     Best := D;
                     FX := Integer (X);
                     FY := Integer (Y);
                  end if;
               end;
            end if;
         end loop;
      end loop;
      if not Found then
         for Y in Y_Pos loop
            for X in X_Pos loop
               if G.Tiles (X, Y).Kind = Floor
                 and then Quadrant (Integer (X), Integer (Y)) = Quad
               then
                  declare
                     D : constant Natural :=
                       abs (Integer (X) - Integer (G.Ghosts (Id).X))
                       + abs (Integer (Y) - Integer (G.Ghosts (Id).Y));
                  begin
                     if D < Best then
                        Best := D;
                        FX := Integer (X);
                        FY := Integer (Y);
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end if;
      TX := FX;
      TY := FY;
   end Cover_Target;

   procedure Cutoff_Target (G : Game; TX, TY : out Integer) is
      CX : Integer := Integer (G.E_X);
      CY : Integer := Integer (G.E_Y);
   begin
      declare
         Left : Integer := G.Params (Cutoff_Lead);
      begin
         while Left > 0 loop
            declare
               NX : constant Integer := CX + G.E_DX;
               NY : constant Integer := CY + G.E_DY;
            begin
               exit when not Open (G, NX, NY);
               CX := NX;
               CY := NY;
            end;
            Left := Left - 1;
         end loop;
      end;
      TX := CX;
      TY := CY;
   end Cutoff_Target;

   procedure Add_Score (G : in out Game; Points : Natural) is
   begin
      pragma Assert (G.Score <= Score_Limit - Points);
      G.Score := G.Score + Points;
   end Add_Score;

   procedure Eat (G : in out Game) is
   begin
      if G.Tiles (G.E_X, G.E_Y).Power then
         G.Tiles (G.E_X, G.E_Y).Power := False;
         pragma Assert (G.Pellets > 0);
         G.Pellets := G.Pellets - 1;
         Add_Score (G, Power_Points);
         G.Ate := True;
         G.Power_Left := G.Params (Fright_Ticks);
         G.Chain := 0;
         Assign_Flee (G);
         for Id in Ghost_Id loop
            if G.Ghosts (Id).Mode /= G_Return then
               G.Ghosts (Id).Mode := G_Flee;
            end if;
         end loop;
         Push_Event (G, Power_Eaten, Integer (G.E_X), Integer (G.E_Y));
      elsif G.Tiles (G.E_X, G.E_Y).Pellet then
         G.Tiles (G.E_X, G.E_Y).Pellet := False;
         pragma Assert (G.Pellets > 0);
         G.Pellets := G.Pellets - 1;
         Add_Score (G, Pellet_Points);
         G.Ate := True;
         Push_Event (G, Pellet_Eaten, Integer (G.E_X), Integer (G.E_Y));
      end if;
      if G.Pellets = 0 and then G.Outcome = Running then
         G.Outcome := Won;
         Push_Event (G, Win, Integer (G.Score), Integer (G.Deaths));
      end if;
   end Eat;

   procedure Note_Death (G : in out Game; By : Ghost_Id) is
      Bits : Natural := 0;
      Slot : Natural;
   begin
      G.Commit_Left := 0;
      if G.Death_Count >= Max_Deaths then
         return;
      end if;
      G.Death_Count := G.Death_Count + 1;
      Slot := G.Death_Count;
      G.Why (Slot).Tick := G.Tick;
      G.Why (Slot).Killer := By;
      G.Why (Slot).Exits :=
        Cell_Exits (G, G.E_X, G.E_Y);
      for Id in Ghost_Id loop
         if abs (Integer (G.Ghosts (Id).X) - Integer (G.E_X))
           + abs (Integer (G.Ghosts (Id).Y) - Integer (G.E_Y)) <= 2
         then
            Bits := Bits + 2 ** (Id - 1);
         end if;
      end loop;
      G.Why (Slot).Near := Bits;
      G.Why (Slot).Choice := G.E_Last.Code;
      G.Why (Slot).Dist_Ago := G.Ago (By, Lookahead);
   end Note_Death;

   procedure Kill (G : in out Game; By : Ghost_Id) is
   begin
      pragma Assert (G.Lives > 0);
      Note_Death (G, By);
      G.Lives := G.Lives - 1;
      G.Deaths := G.Deaths + 1;
      G.Power_Left := 0;
      G.Chain := 0;
      Push_Event (G, Death, Integer (G.Lives), By);
      if G.Lives = 0 then
         G.Outcome := Lost;
         Push_Event (G, Lose, Integer (G.Score), Integer (G.Pellets));
         return;
      end if;
      G.E_X := G.Spawn_X;
      G.E_Y := G.Spawn_Y;
      G.E_DX := 1;
      G.E_DY := 0;
      for Id in Ghost_Id loop
         G.Ghosts (Id).X := G.Ghosts (Id).Home_X;
         G.Ghosts (Id).Y := G.Ghosts (Id).Home_Y;
         G.Ghosts (Id).DX := 0;
         G.Ghosts (Id).DY := 0;
         G.Ghosts (Id).Mode := Role (G, Id);
      end loop;
      G.Respawn_Pause := Respawn_Pause_Ticks;
   end Kill;

   procedure Catch (G : in out Game; Id : Ghost_Id) is
      Points : constant Natural := Catch_Points (G.Chain);
   begin
      Add_Score (G, Points);
      G.Catches := G.Catches + 1;
      if G.Chain < 3 then
         G.Chain := G.Chain + 1;
      end if;
      G.Ghosts (Id).Mode := G_Return;
      Push_Event (G, Catch, Id, Integer (Points));
   end Catch;

   procedure Resolve (G : in out Game) is
   begin
      if G.Outcome /= Running then
         return;
      end if;
      for Id in Ghost_Id loop
         if G.Ghosts (Id).X = G.E_X and then G.Ghosts (Id).Y = G.E_Y then
            if G.Ghosts (Id).Mode = G_Return then
               null;
            elsif G.Ghosts (Id).Mode = G_Flee then
               Catch (G, Id);
            else
               Kill (G, Id);
               return;
            end if;
         end if;
      end loop;
   end Resolve;

   procedure Step_Eater (G : in out Game; NX, NY : Integer) is
   begin
      if NX = Integer (G.E_X) and then NY = Integer (G.E_Y) then
         return;
      end if;
      pragma Assert (Open (G, NX, NY));
      pragma Assert
        (abs (NX - Integer (G.E_X)) + abs (NY - Integer (G.E_Y)) = 1);
      G.E_DX := NX - Integer (G.E_X);
      G.E_DY := NY - Integer (G.E_Y);
      G.E_X := X_Pos (NX);
      G.E_Y := Y_Pos (NY);
   end Step_Eater;

   procedure Step_Ghost (G : in out Game; Id : Ghost_Id; NX, NY : Integer) is
   begin
      if NX = Integer (G.Ghosts (Id).X)
        and then NY = Integer (G.Ghosts (Id).Y)
      then
         return;
      end if;
      pragma Assert (Open (G, NX, NY));
      pragma Assert
        (abs (NX - Integer (G.Ghosts (Id).X))
         + abs (NY - Integer (G.Ghosts (Id).Y)) = 1);
      G.Ghosts (Id).DX := NX - Integer (G.Ghosts (Id).X);
      G.Ghosts (Id).DY := NY - Integer (G.Ghosts (Id).Y);
      G.Ghosts (Id).X := X_Pos (NX);
      G.Ghosts (Id).Y := Y_Pos (NY);
   end Step_Ghost;

   procedure Move_Eater (G : in out Game) is
      Order : constant Natural := G.Eater_Bias;
      Within : Natural := G.Params (Danger_Radius);
      Pred_X : array (Ghost_Id, 1 .. Lookahead) of Integer;
      Pred_Y : array (Ghost_Id, 1 .. Lookahead) of Integer;

      function Hostile (Id : Ghost_Id) return Boolean is
        (G.Ghosts (Id).Mode /= G_Return and then G.Ghosts (Id).Mode /= G_Flee);

      procedure Aim (Id : Ghost_Id; TX, TY : out Integer) is
      begin
         if G.Ghosts (Id).Mode = G_Return then
            TX := Integer (G.Ghosts (Id).Home_X);
            TY := Integer (G.Ghosts (Id).Home_Y);
         elsif G.Ghosts (Id).Mode = G_Flee then
            TX := G.Flee_X (Id);
            TY := G.Flee_Y (Id);
         else
            case Role (G, Id) is
               when G_Chase =>
                  TX := Integer (G.E_X);
                  TY := Integer (G.E_Y);
               when G_Cutoff =>
                  Cutoff_Target (G, TX, TY);
               when G_Cover =>
                  Cover_Target (G, Id, TX, TY);
               when G_Flee | G_Return =>
                  TX := Integer (G.E_X);
                  TY := Integer (G.E_Y);
            end case;
         end if;
      end Aim;

      procedure Fill_Pred is
         Already : constant Boolean := G.Power_Left > 0;
         Stride : constant Integer := G.Params (Ghost_Stride);
      begin
         for Id in Ghost_Id loop
            declare
               SX : Integer := Integer (G.Ghosts (Id).X);
               SY : Integer := Integer (G.Ghosts (Id).Y);
            begin
               for Step in 1 .. Lookahead loop
                  declare
                     Future : Natural;
                     TX, TY, GX, GY, Dist, NX, NY : Integer;
                     Found : Boolean;
                  begin
                     if Already then
                        Future := G.Tick + Step;
                     else
                        Future := G.Tick + Step - 1;
                     end if;
                     if Stride >= 1 and then Future mod Stride = 0
                       and then Hostile (Id)
                     then
                        Aim (Id, TX, TY);
                        Seek_From
                          (G, SX, SY, Seek_Cell, TX, TY, G.Bias,
                           False, False, False, False,
                           Found, GX, GY, Dist, NX, NY);
                        if Found and then Open (G, NX, NY)
                          and then abs (NX - SX) + abs (NY - SY) = 1
                        then
                           SX := NX;
                           SY := NY;
                        end if;
                     end if;
                     Pred_X (Id, Step) := SX;
                     Pred_Y (Id, Step) := SY;
                  end;
               end loop;
            end;
         end loop;
      end Fill_Pred;

      function Hits (Id : Ghost_Id; X, Y : Integer) return Boolean is
      begin
         if not Hostile (Id) then
            return False;
         end if;
         for Step in 1 .. Within loop
            if Pred_X (Id, Step) = X and then Pred_Y (Id, Step) = Y then
               return True;
            end if;
         end loop;
         return False;
      end Hits;

      function Step_Fatal (X, Y : Integer) return Boolean is
      begin
         for Id in Ghost_Id loop
            if Hostile (Id)
              and then ((Integer (G.Ghosts (Id).X) = X
                         and then Integer (G.Ghosts (Id).Y) = Y)
                        or else (Pred_X (Id, 1) = X and then Pred_Y (Id, 1) = Y))
            then
               return True;
            end if;
         end loop;
         return False;
      end Step_Fatal;

      function Reaches_Us return Boolean is
      begin
         for Id in Ghost_Id loop
            if Hits (Id, Integer (G.E_X), Integer (G.E_Y)) then
               return True;
            end if;
         end loop;
         return False;
      end Reaches_Us;

      function Safe_Exits return Natural is
         N : Natural := 0;
      begin
         for K in 0 .. 3 loop
            declare
               NX : constant Integer := Integer (G.E_X) + Dirs (K).DX;
               NY : constant Integer := Integer (G.E_Y) + Dirs (K).DY;
               Threatened : Boolean := False;
            begin
               if Open (G, NX, NY) then
                  for Id in Ghost_Id loop
                     if Hits (Id, NX, NY) then
                        Threatened := True;
                     end if;
                  end loop;
                  if not Threatened then
                     N := N + 1;
                  end if;
               end if;
            end;
         end loop;
         return N;
      end Safe_Exits;

      function Pincer return Boolean is
         Seen : array (Ghost_Id) of Boolean := [others => False];
         Ghosts : Natural := 0;
         Exits : Natural := 0;
      begin
         for K in 0 .. 3 loop
            declare
               NX : constant Integer := Integer (G.E_X) + Dirs (K).DX;
               NY : constant Integer := Integer (G.E_Y) + Dirs (K).DY;
               Hit_Here : Boolean := False;
            begin
               if Open (G, NX, NY) then
                  for Id in Ghost_Id loop
                     if Hits (Id, NX, NY) then
                        Hit_Here := True;
                        if not Seen (Id) then
                           Seen (Id) := True;
                           Ghosts := Ghosts + 1;
                        end if;
                     end if;
                  end loop;
                  if Hit_Here then
                     Exits := Exits + 1;
                  end if;
               end if;
            end;
         end loop;
         return Ghosts >= 2 and then Exits >= 2;
      end Pincer;

      procedure Escape_Target (SX, SY, TX, TY : out Integer) is
         Best : Integer := -1;
         DX : Integer := 0;
         DY : Integer := 0;
      begin
         SX := Integer (G.E_X);
         SY := Integer (G.E_Y);
         TX := SX;
         TY := SY;
         for K in 0 .. 3 loop
            declare
               Dir : constant Step := Dirs ((K + Order) mod 4);
               NX : constant Integer := Integer (G.E_X) + Dir.DX;
               NY : constant Integer := Integer (G.E_Y) + Dir.DY;
               Score : Integer := Lookahead + 1;
            begin
               if Open (G, NX, NY) and then not Lethal_Cell (G, NX, NY) then
                  for Step in 1 .. Lookahead loop
                     for Id in Ghost_Id loop
                        if Hostile (Id)
                          and then Pred_X (Id, Step) = NX
                          and then Pred_Y (Id, Step) = NY
                          and then Step < Score
                        then
                           Score := Step;
                        end if;
                     end loop;
                  end loop;
                  if Score > Best then
                     Best := Score;
                     SX := NX;
                     SY := NY;
                     DX := Dir.DX;
                     DY := Dir.DY;
                  end if;
               end if;
            end;
         end loop;
         declare
            CX : Integer := Integer (G.E_X);
            CY : Integer := Integer (G.E_Y);
         begin
            for Step in 1 .. Lookahead loop
               declare
                  NX : constant Integer := CX + DX;
                  NY : constant Integer := CY + DY;
               begin
                  exit when not Open (G, NX, NY);
                  CX := NX;
                  CY := NY;
               end;
            end loop;
            TX := CX;
            TY := CY;
         end;
      end Escape_Target;

      procedure Find_Food
        (Have : out Boolean; FX, FY, FD, SX, SY : out Integer)
      is
      begin
         Seek_From
           (G, Integer (G.E_X), Integer (G.E_Y), Seek_Food, 0, 0,
            Order, True, True, True, True, Have, FX, FY, FD, SX, SY);
         if not Have then
            Seek_From
              (G, Integer (G.E_X), Integer (G.E_Y), Seek_Food, 0, 0,
               Order, True, False, True, True, Have, FX, FY, FD, SX, SY);
         end if;
         if not Have then
            Seek_From
              (G, Integer (G.E_X), Integer (G.E_Y), Seek_Food, 0, 0,
               Order, False, True, True, True, Have, FX, FY, FD, SX, SY);
         end if;
         if not Have then
            Seek_From
              (G, Integer (G.E_X), Integer (G.E_Y), Seek_Food, 0, 0,
               Order, False, False, True, True, Have, FX, FY, FD, SX, SY);
         end if;
      end Find_Food;

      procedure Finish
        (Code : Decision_Code; TX, TY, SX, SY : Integer; Hold : Natural)
      is
         UX : Integer := SX;
         UY : Integer := SY;

         function Allowed (X, Y : Integer; Allow_Power : Boolean) return Boolean is
           (Open (G, X, Y) and then not Lethal_Cell (G, X, Y)
            and then (Allow_Power or else not Power_At (G, X, Y)));
      begin
         -- A power pellet is an allowed step when staying would be fatal.
         if not Allowed (UX, UY, Code = Seek_Power
                         or else Lethal_Cell (G, Integer (G.E_X), Integer (G.E_Y)))
         then
            declare
               Alt : Boolean := False;
               Danger : constant Boolean :=
                 Lethal_Cell (G, Integer (G.E_X), Integer (G.E_Y));
            begin
               for K in 0 .. 3 loop
                  declare
                     Dir : constant Step := Dirs ((K + Order) mod 4);
                     NX : constant Integer := Integer (G.E_X) + Dir.DX;
                     NY : constant Integer := Integer (G.E_Y) + Dir.DY;
                  begin
                     if Allowed (NX, NY, False) then
                        UX := NX;
                        UY := NY;
                        Alt := True;
                        exit;
                     end if;
                  end;
               end loop;
               if not Alt and then (Danger or else Code = Seek_Power) then
                  for K in 0 .. 3 loop
                     declare
                        Dir : constant Step := Dirs ((K + Order) mod 4);
                        NX : constant Integer := Integer (G.E_X) + Dir.DX;
                        NY : constant Integer := Integer (G.E_Y) + Dir.DY;
                     begin
                        if Allowed (NX, NY, True) then
                           UX := NX;
                           UY := NY;
                           Alt := True;
                           exit;
                        end if;
                     end;
                  end loop;
               end if;
               if not Alt then
                  UX := Integer (G.E_X);
                  UY := Integer (G.E_Y);
               end if;
            end;
         end if;
         -- A lethal step is only allowed when every open neighbour is lethal too.
         if Lethal_Cell (G, UX, UY) then
            declare
               Safe : Boolean :=
                 not Lethal_Cell (G, Integer (G.E_X), Integer (G.E_Y));
            begin
               for K in 0 .. 3 loop
                  declare
                     Dir : constant Step := Dirs (K);
                     NX : constant Integer := Integer (G.E_X) + Dir.DX;
                     NY : constant Integer := Integer (G.E_Y) + Dir.DY;
                  begin
                     if Open (G, NX, NY) and then not Lethal_Cell (G, NX, NY) then
                        Safe := True;
                     end if;
                  end;
               end loop;
               pragma Assert (not Safe);
            end;
         end if;
         Note_Choice (G, G.E_Last, 0, Code, TX, TY);
         Step_Eater (G, UX, UY);
         if Hold > 1 then
            G.Commit_Code := Code;
            G.Commit_X := TX;
            G.Commit_Y := TY;
            G.Commit_Left := Hold - 1;
         else
            G.Commit_Left := 0;
         end if;
         if G.Outcome = Running then
            Eat (G);
         end if;
         if G.Outcome = Running then
            Resolve (G);
         end if;
      end Finish;

      function Catchable return Boolean is
         D : Dist_Map;
         Any : Boolean;
      begin
         Hostile_Map (G, D, Any);
         if not Any or else D (G.E_X, G.E_Y) = Unseen then
            return False;
         end if;
         -- Close enough that spending a power pellet can catch them.
         -- Fright lasts longer than this; a ghost anywhere on the maze is not "near".
         return D (G.E_X, G.E_Y) <= G.Params (Danger_Radius);
      end Catchable;

      Have_Food, Have_Power, Have_Hunt : Boolean;
      Food_D, Power_D, Hunt_D : Integer;
      Food_X, Food_Y, Power_X, Power_Y, Hunt_X, Hunt_Y : Integer;
      Food_SX, Food_SY, Power_SX, Power_SY, Hunt_SX, Hunt_SY : Integer;
      Esc_SX, Esc_SY, Esc_TX, Esc_TY : Integer;
   begin
      if G.Outcome /= Running then
         return;
      end if;
      if Within > Lookahead then
         Within := Lookahead;
      end if;
      if Within < 1 then
         Within := 1;
      end if;
      Fill_Pred;
      if G.Commit_Left > 0 and then G.Commit_Code = Seek_Power
        and then not (Pincer or else Reaches_Us or else Safe_Exits = 0
                      or else Catchable)
      then
         G.Commit_Left := 0;
      end if;
      if G.Commit_Left > 0 then
         declare
            Found : Boolean;
            GX, GY, Dist, SX, SY : Integer;
         begin
            Seek_From
              (G, Integer (G.E_X), Integer (G.E_Y), Seek_Cell,
               G.Commit_X, G.Commit_Y, Order, False, False, True,
               G.Commit_Code /= Seek_Power,
               Found, GX, GY, Dist, SX, SY);
            if Found and then not Step_Fatal (SX, SY)
              and then not Lethal_Cell (G, SX, SY)
              and then (SX /= Integer (G.E_X) or else SY /= Integer (G.E_Y))
            then
               Finish (G.Commit_Code, G.Commit_X, G.Commit_Y, SX, SY, G.Commit_Left);
               return;
            end if;
            G.Commit_Left := 0;
         end;
      end if;
      Find_Food (Have_Food, Food_X, Food_Y, Food_D, Food_SX, Food_SY);
      Seek_From
        (G, Integer (G.E_X), Integer (G.E_Y), Seek_Power, 0, 0,
         Order, False, False, True, False,
         Have_Power, Power_X, Power_Y, Power_D, Power_SX, Power_SY);
      Seek_From
        (G, Integer (G.E_X), Integer (G.E_Y), Seek_Fright, 0, 0,
         Order, False, False, True, True,
         Have_Hunt, Hunt_X, Hunt_Y, Hunt_D, Hunt_SX, Hunt_SY);
      if G.Power_Left > 0 and then Have_Hunt
        and then Hunt_D <= G.Params (Hunt_Range)
        and then Hunt_D <= G.Power_Left
        and then G.Ticks_Since_Eat < G.Params (Starve_Ticks)
        and then (not Have_Food or else Hunt_D < Food_D)
      then
         Finish (Hunt, Hunt_X, Hunt_Y, Hunt_SX, Hunt_SY, 0);
      elsif G.Power_Left = 0 and then Have_Power
        and then (Pincer or else Reaches_Us or else Safe_Exits = 0
                  or else (Power_D <= G.Params (Power_Seek) and then Catchable))
      then
         Finish (Seek_Power, Power_X, Power_Y, Power_SX, Power_SY, Commit_Ticks);
      elsif G.Power_Left = 0
        and then (Pincer or else Reaches_Us or else Safe_Exits = 0)
      then
         Escape_Target (Esc_SX, Esc_SY, Esc_TX, Esc_TY);
         Finish (Flee, Esc_TX, Esc_TY, Esc_SX, Esc_SY, Commit_Ticks);
      elsif Have_Food then
         Finish (Seek_Pellet, Food_X, Food_Y, Food_SX, Food_SY, 0);
      else
         Finish (Seek_Pellet, Integer (G.E_X), Integer (G.E_Y),
                 Integer (G.E_X), Integer (G.E_Y), 0);
      end if;
   end Move_Eater;

   procedure Move_One_Ghost (G : in out Game; Id : Ghost_Id) is
      Code : Decision_Code;
      TX, TY : Integer;
      Found : Boolean;
      GX, GY, Dist, SX, SY : Integer;
   begin
      if G.Outcome /= Running then
         return;
      end if;
      if G.Ghosts (Id).Mode = G_Return
        and then G.Ghosts (Id).X = G.Ghosts (Id).Home_X
        and then G.Ghosts (Id).Y = G.Ghosts (Id).Home_Y
      then
         if G.Power_Left > 0 then
            G.Ghosts (Id).Mode := G_Flee;
         else
            G.Ghosts (Id).Mode := Role (G, Id);
         end if;
      end if;
      if G.Ghosts (Id).Mode = G_Return then
         Code := Return_Home;
         TX := Integer (G.Ghosts (Id).Home_X);
         TY := Integer (G.Ghosts (Id).Home_Y);
      elsif G.Ghosts (Id).Mode = G_Flee then
         Code := Ghost_Flee;
         TX := G.Flee_X (Id);
         TY := G.Flee_Y (Id);
      else
         G.Ghosts (Id).Mode := Role (G, Id);
         case G.Ghosts (Id).Mode is
            when G_Chase =>
               Code := Chase;
               TX := Integer (G.E_X);
               TY := Integer (G.E_Y);
            when G_Cutoff =>
               Code := Cutoff;
               Cutoff_Target (G, TX, TY);
            when G_Cover =>
               Code := Cover;
               Cover_Target (G, Id, TX, TY);
            when G_Flee =>
               Code := Ghost_Flee;
               TX := G.Flee_X (Id);
               TY := G.Flee_Y (Id);
            when G_Return =>
               Code := Return_Home;
               TX := Integer (G.Ghosts (Id).Home_X);
               TY := Integer (G.Ghosts (Id).Home_Y);
         end case;
      end if;
      Seek_From
        (G, Integer (G.Ghosts (Id).X), Integer (G.Ghosts (Id).Y),
         Seek_Cell, TX, TY, G.Bias, False, False, False, False,
         Found, GX, GY, Dist, SX, SY);
      if not Found then
         SX := Integer (G.Ghosts (Id).X);
         SY := Integer (G.Ghosts (Id).Y);
      end if;
      Note_Choice (G, G.Ghosts (Id).Last, Id, Code, TX, TY);
      Step_Ghost (G, Id, SX, SY);
      if G.Outcome = Running then
         Resolve (G);
      end if;
   end Move_One_Ghost;

   procedure Move_Ghosts (G : in out Game) is
   begin
      if G.Outcome /= Running then
         return;
      end if;
      pragma Assert (G.Params (Ghost_Stride) >= 1);
      if G.Tick mod G.Params (Ghost_Stride) /= 0 then
         return;
      end if;
      G.Role_Timer := G.Role_Timer + 1;
      if G.Role_Timer >= G.Params (Role_Interval) then
         Assign_Cover (G);
         G.Role_Timer := 0;
      end if;
      for Id in Ghost_Id loop
         exit when G.Outcome /= Running;
         Move_One_Ghost (G, Id);
      end loop;
   end Move_Ghosts;

   procedure Clear_Logs (G : in out Game) is
   begin
      G.Dec_Next := 1;
      G.Dec_Count := 0;
      G.Dec_Dropped := 0;
      G.Ev_Next := 1;
      G.Ev_Count := 0;
      G.Ev_Dropped := 0;
      G.E_Last := (Code => None, X => 0, Y => 0, Tick => 0);
      for Id in Ghost_Id loop
         G.Ghosts (Id).Last := (Code => None, X => 0, Y => 0, Tick => 0);
      end loop;
   end Clear_Logs;

   procedure Assert_Reachable (G : Game) is
      Seen : array (X_Pos, Y_Pos) of Boolean := [others => [others => False]];
      QX : array (0 .. Width * Height - 1) of X_Pos;
      QY : array (0 .. Width * Height - 1) of Y_Pos;
      Head, Tail : Natural := 0;
   begin
      Seen (G.E_X, G.E_Y) := True;
      QX (0) := G.E_X;
      QY (0) := G.E_Y;
      Tail := 1;
      while Head /= Tail loop
         declare
            CX : constant X_Pos := QX (Head);
            CY : constant Y_Pos := QY (Head);
         begin
            Head := Head + 1;
            for K in 0 .. 3 loop
               declare
                  NX : constant Integer := Integer (CX) + Dirs (K).DX;
                  NY : constant Integer := Integer (CY) + Dirs (K).DY;
               begin
                  if Open (G, NX, NY) and then not Seen (X_Pos (NX), Y_Pos (NY))
                  then
                     pragma Assert (Tail < QX'Length);
                     Seen (X_Pos (NX), Y_Pos (NY)) := True;
                     QX (Tail) := X_Pos (NX);
                     QY (Tail) := Y_Pos (NY);
                     Tail := Tail + 1;
                  end if;
               end;
            end loop;
         end;
      end loop;
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power then
               pragma Assert (Seen (X, Y));
            end if;
         end loop;
      end loop;
   end Assert_Reachable;

   procedure Set_Param
     (G : in out Game; Index : Integer; Value : Integer; OK : out Boolean)
   is
   begin
      Ensure (G);
      OK := False;
      if Index not in Param_Index then
         return;
      end if;
      if Value < Min_Param (Index) or else Value > Max_Param (Index) then
         return;
      end if;
      G.Params (Index) := Value;
      OK := True;
   end Set_Param;

   procedure Paint_Hand (G : in out Game) is
   begin
      for Y in Y_Pos loop
         for X in X_Pos loop
            declare
               C : constant Character :=
                 Maze (Integer (Y) + 1) (Integer (X) + 1);
            begin
               G.Tiles (X, Y) := (Kind => Wall, Pellet => False, Power => False);
               if C /= '#' then
                  G.Tiles (X, Y).Kind := Floor;
                  if C = 'o' then
                     G.Tiles (X, Y).Power := True;
                  elsif C = '.' then
                     G.Tiles (X, Y).Pellet := True;
                  end if;
               end if;
            end;
         end loop;
      end loop;
   end Paint_Hand;

   procedure Paint_Generated (G : in out Game; Seed : Interfaces.Unsigned_32) is
      Room_Cols : constant := 9;
      Room_Rows : constant := 10;
      Room_N : constant := Room_Cols * Room_Rows;
      Max_Edges : constant := 200;
      type Edge is record
         A, B : Natural;
         MX, MY : Natural;
      end record;
      type Edge_List is array (0 .. Max_Edges - 1) of Edge;
      Edges : Edge_List;
      Carved : array (0 .. Max_Edges - 1) of Boolean := [others => False];
      Parent : array (0 .. Room_N - 1) of Natural;
      Edge_Count : Natural := 0;
      Rng : Interfaces.Unsigned_32 := Seed;

      procedure Next is
      begin
         Rng := Rng * 1664525 + 1013904223;
      end Next;

      function Find (Start : Natural) return Natural is
         Y : Natural := Start;
      begin
         while Parent (Y) /= Y loop
            Parent (Y) := Parent (Parent (Y));
            Y := Parent (Y);
         end loop;
         return Y;
      end Find;

      procedure Make_Floor (X, Y : Natural) is
      begin
         pragma Assert (X <= Natural (X_Pos'Last));
         pragma Assert (Y <= Natural (Y_Pos'Last));
         G.Tiles (X_Pos (X), Y_Pos (Y)) :=
           (Kind => Floor, Pellet => True, Power => False);
      end Make_Floor;

      function Room_X (I : Natural) return Natural is
        (1 + (I mod Room_Cols) * 2);

      function Room_Y (I : Natural) return Natural is
        (1 + (I / Room_Cols) * 2);
   begin
      pragma Assert (Seed /= 0);
      for Y in Y_Pos loop
         for X in X_Pos loop
            G.Tiles (X, Y) := (Kind => Wall, Pellet => False, Power => False);
         end loop;
      end loop;
      for I in 0 .. Room_N - 1 loop
         Parent (I) := I;
         Make_Floor (Room_X (I), Room_Y (I));
      end loop;
      for R in 0 .. Room_N - 1 loop
         declare
            X : constant Natural := Room_X (R);
            Y : constant Natural := Room_Y (R);
         begin
            if X + 2 < Width then
               pragma Assert (Edge_Count < Max_Edges);
               Edges (Edge_Count) := (A => R, B => R + 1, MX => X + 1, MY => Y);
               Edge_Count := Edge_Count + 1;
            end if;
            if Y + 2 < Height then
               pragma Assert (Edge_Count < Max_Edges);
               Edges (Edge_Count) :=
                 (A => R, B => R + Room_Cols, MX => X, MY => Y + 1);
               Edge_Count := Edge_Count + 1;
            end if;
         end;
      end loop;
      if Edge_Count > 1 then
         for I in reverse 1 .. Edge_Count - 1 loop
            declare
               J : Natural;
               Tmp : Edge;
            begin
               Next;
               J := Natural (Rng mod Interfaces.Unsigned_32 (I + 1));
               Tmp := Edges (I);
               Edges (I) := Edges (J);
               Edges (J) := Tmp;
            end;
         end loop;
      end if;
      for I in 0 .. Edge_Count - 1 loop
         declare
            FA : constant Natural := Find (Edges (I).A);
            FB : constant Natural := Find (Edges (I).B);
         begin
            if FA /= FB then
               Parent (FA) := FB;
               Make_Floor (Edges (I).MX, Edges (I).MY);
               Carved (I) := True;
            end if;
         end;
      end loop;
      for I in 0 .. Edge_Count - 1 loop
         if not Carved (I) then
            Next;
            if Rng mod 5 = 0 then
               Make_Floor (Edges (I).MX, Edges (I).MY);
            end if;
         end if;
      end loop;
      for Q in 1 .. 4 loop
         declare
            CX : constant Integer := (if Q mod 2 = 1 then 4 else 14);
            CY : constant Integer := (if Q <= 2 then 5 else 15);
            Best : Natural := Natural'Last;
            BX : X_Pos := 1;
            BY : Y_Pos := 1;
            Found : Boolean := False;
         begin
            for Y in Y_Pos loop
               for X in X_Pos loop
                  if G.Tiles (X, Y).Kind = Floor and then not G.Tiles (X, Y).Power
                  then
                     declare
                        In_Q : constant Boolean :=
                          (Q = 1 and then Integer (X) < Width / 2
                           and then Integer (Y) < Height / 2)
                          or else (Q = 2 and then Integer (X) >= Width / 2
                                   and then Integer (Y) < Height / 2)
                          or else (Q = 3 and then Integer (X) < Width / 2
                                   and then Integer (Y) >= Height / 2)
                          or else (Q = 4 and then Integer (X) >= Width / 2
                                   and then Integer (Y) >= Height / 2);
                        D : constant Natural :=
                          abs (Integer (X) - CX) + abs (Integer (Y) - CY);
                     begin
                        if In_Q and then D < Best then
                           Best := D;
                           BX := X;
                           BY := Y;
                           Found := True;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            if Found then
               G.Tiles (BX, BY).Power := True;
               G.Tiles (BX, BY).Pellet := False;
            end if;
         end;
      end loop;
   end Paint_Generated;

   procedure Start
     (G : in out Game; Grid_Seed, Eater_Seed, Ghost_Seed : Interfaces.Unsigned_32)
   is
      type Point is record
         X : X_Pos;
         Y : Y_Pos;
      end record;
      Floors : array (0 .. Width * Height - 1) of Point;
      Floor_Count : Natural := 0;
      Used : array (X_Pos, Y_Pos) of Boolean := [others => [others => False]];
      Corners : constant array (1 .. 4) of Point :=
        [1 => (X => 0, Y => 0),
         2 => (X => Width - 1, Y => 0),
         3 => (X => 0, Y => Height - 1),
         4 => (X => Width - 1, Y => Height - 1)];
   begin
      Ensure (G);
      G.Started := False;
      G.Grid_Seed := Grid_Seed;
      G.Eater_Seed := Eater_Seed;
      G.Ghost_Seed := Ghost_Seed;
      G.Bias := Natural (Ghost_Seed mod 4);
      G.Eater_Bias := Natural (Eater_Seed mod 4);
      G.Commit_Left := 0;
      G.Death_Count := 0;
      G.Tick := 0;
      G.Score := 0;
      G.Lives := 0;
      G.Deaths := 0;
      G.Catches := 0;
      G.Pellets := 0;
      G.Power_Left := 0;
      G.Chain := 0;
      G.Ticks_Since_Eat := 0;
      G.Ate := False;
      G.Respawn_Pause := 0;
      G.Outcome := Running;
      G.Role_Timer := 0;
      G.Error_Used := False;
      G.Error_Line := 0;
      G.E_DX := 1;
      G.E_DY := 0;
      Clear_Logs (G);
      if Grid_Seed = 0 then
         Paint_Hand (G);
      else
         Paint_Generated (G, Grid_Seed);
      end if;
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Kind = Floor then
               Floors (Floor_Count) := (X => X, Y => Y);
               Floor_Count := Floor_Count + 1;
            end if;
         end loop;
      end loop;
      pragma Assert (Floor_Count > 4);
      for N in 1 .. 4 loop
         declare
            Best_D : Natural := Natural'Last;
            Best_X : X_Pos := 0;
            Best_Y : Y_Pos := 0;
            Found : Boolean := False;
            Goal_X : constant Integer := Integer (Corners (N).X);
            Goal_Y : constant Integer := Integer (Corners (N).Y);
         begin
            for I in 0 .. Floor_Count - 1 loop
               if not Used (Floors (I).X, Floors (I).Y) then
                  declare
                     D : constant Natural :=
                       abs (Integer (Floors (I).X) - Goal_X)
                       + abs (Integer (Floors (I).Y) - Goal_Y);
                  begin
                     if not Found or else D < Best_D then
                        Found := True;
                        Best_D := D;
                        Best_X := Floors (I).X;
                        Best_Y := Floors (I).Y;
                     end if;
                  end;
               end if;
            end loop;
            pragma Assert (Found);
            Used (Best_X, Best_Y) := True;
            G.Ghosts (N).Home_X := Best_X;
            G.Ghosts (N).Home_Y := Best_Y;
            G.Ghosts (N).X := Best_X;
            G.Ghosts (N).Y := Best_Y;
            G.Ghosts (N).DX := 0;
            G.Ghosts (N).DY := 0;
         end;
      end loop;
      declare
         Index : Natural :=
           Natural (Eater_Seed mod Interfaces.Unsigned_32 (Floor_Count));
         Chosen : Boolean := False;
      begin
         for Attempt in 1 .. Floor_Count loop
            declare
               P : constant Point := Floors (Index);
            begin
               if not Used (P.X, P.Y) then
                  G.E_X := P.X;
                  G.E_Y := P.Y;
                  G.Spawn_X := P.X;
                  G.Spawn_Y := P.Y;
                  Chosen := True;
                  exit;
               end if;
            end;
            Index := Index + 1;
            if Index = Floor_Count then
               Index := 0;
            end if;
         end loop;
         pragma Assert (Chosen);
      end;
      G.Tiles (G.E_X, G.E_Y).Pellet := False;
      G.Tiles (G.E_X, G.E_Y).Power := False;
      for Id in Ghost_Id loop
         G.Tiles (G.Ghosts (Id).X, G.Ghosts (Id).Y).Pellet := False;
         G.Tiles (G.Ghosts (Id).X, G.Ghosts (Id).Y).Power := False;
      end loop;
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power then
               G.Pellets := G.Pellets + 1;
            end if;
         end loop;
      end loop;
      Assert_Reachable (G);
      G.Lives := Initial_Lives;
      Assign_Cover (G);
      Assign_Flee (G);
      for Id in Ghost_Id loop
         G.Ghosts (Id).Mode := Role (G, Id);
      end loop;
      G.Started := True;
      Push_Event (G, Game_Start, Integer (G.Bias), Integer (G.Pellets));
   end Start;

   procedure Tick (G : in out Game) is
      Old_Score : constant Natural := G.Score;
      Old_Lives : constant Natural := G.Lives;
      Old_Tick  : constant Natural := G.Tick;
   begin
      if not G.Started or else G.Outcome /= Running then
         return;
      end if;
      G.Tick := G.Tick + 1;
      G.Ate := False;
      for Id in Ghost_Id loop
         for T in reverse 2 .. Lookahead loop
            G.Ago (Id, T) := G.Ago (Id, T - 1);
         end loop;
         G.Ago (Id, 1) :=
           abs (Integer (G.Ghosts (Id).X) - Integer (G.E_X))
           + abs (Integer (G.Ghosts (Id).Y) - Integer (G.E_Y));
      end loop;
      if G.Respawn_Pause > 0 then
         G.Respawn_Pause := G.Respawn_Pause - 1;
      elsif G.Power_Left > 0 then
         Move_Ghosts (G);
         if G.Outcome = Running then
            Move_Eater (G);
         end if;
      else
         Move_Eater (G);
         if G.Outcome = Running then
            Move_Ghosts (G);
         end if;
      end if;
      if G.Outcome = Running and then G.Power_Left > 0
        and then G.Respawn_Pause = 0
      then
         G.Power_Left := G.Power_Left - 1;
         if G.Power_Left = 0 then
            G.Chain := 0;
            Push_Event (G, Fright_End, 0, 0);
            for Id in Ghost_Id loop
               if G.Ghosts (Id).Mode = G_Flee then
                  G.Ghosts (Id).Mode := Role (G, Id);
               end if;
            end loop;
         end if;
      end if;
      if G.Ate then
         G.Ticks_Since_Eat := 0;
      else
         G.Ticks_Since_Eat := G.Ticks_Since_Eat + 1;
      end if;
      if G.Outcome = Running and then G.Tick >= Tick_Cap then
         G.Outcome := Timed_Out;
         Push_Event (G, Timeout, Integer (G.Score), Integer (G.Pellets));
      end if;
      pragma Assert (G.Score >= Old_Score);
      pragma Assert (G.Lives <= Old_Lives);
      pragma Assert (G.Tick > Old_Tick);
   end Tick;

   function Param (G : Game; Index : Integer) return Integer is
   begin
      if Index not in Param_Index then
         return 0;
      end if;
      if not G.Defaults_Ready then
         return Default_Param (Index);
      end if;
      return G.Params (Index);
   end Param;

   function Param_Min (Index : Integer) return Integer is
   begin
      if Index not in Param_Index then
         return 0;
      end if;
      return Min_Param (Index);
   end Param_Min;

   function Param_Max (Index : Integer) return Integer is
   begin
      if Index not in Param_Index then
         return 0;
      end if;
      return Max_Param (Index);
   end Param_Max;

   function Started (G : Game) return Boolean is (G.Started);

   function Outcome (G : Game) return Outcome_Kind is
   begin
      if not G.Started then
         return Running;
      end if;
      return G.Outcome;
   end Outcome;

   function Score (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Score;
   end Score;

   function Lives (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Lives;
   end Lives;

   function Deaths (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Deaths;
   end Deaths;

   function Catches (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Catches;
   end Catches;

   function Tick_Count (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Tick;
   end Tick_Count;

   function Pellets_Left (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Pellets;
   end Pellets_Left;

   function Power_Left (G : Game) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.Power_Left;
   end Power_Left;

   function State_Hash (G : Game) return Interfaces.Unsigned_32 is
      H : Interfaces.Unsigned_32 := 2166136261;
      procedure Mix (V : Interfaces.Unsigned_32) is
      begin
         H := (H xor V) * 16777619;
      end Mix;
   begin
      if not G.Started then
         return 0;
      end if;
      Mix (G.Grid_Seed);
      Mix (G.Eater_Seed);
      Mix (G.Ghost_Seed);
      Mix (Interfaces.Unsigned_32 (G.Bias));
      Mix (Interfaces.Unsigned_32 (G.Eater_Bias));
      Mix (Interfaces.Unsigned_32 (G.Tick));
      Mix (Interfaces.Unsigned_32 (G.Score));
      Mix (Interfaces.Unsigned_32 (G.Lives));
      Mix (Interfaces.Unsigned_32 (G.Deaths));
      Mix (Interfaces.Unsigned_32 (G.Pellets));
      Mix (Interfaces.Unsigned_32 (G.Power_Left));
      Mix (Interfaces.Unsigned_32 (Outcome_Kind'Pos (G.Outcome)));
      Mix (Interfaces.Unsigned_32 (Integer (G.E_X)));
      Mix (Interfaces.Unsigned_32 (Integer (G.E_Y)));
      Mix (Interfaces.Unsigned_32 (G.E_DX + 1));
      Mix (Interfaces.Unsigned_32 (G.E_DY + 1));
      for Id in Ghost_Id loop
         Mix (Interfaces.Unsigned_32 (Integer (G.Ghosts (Id).X)));
         Mix (Interfaces.Unsigned_32 (Integer (G.Ghosts (Id).Y)));
         Mix (Interfaces.Unsigned_32 (Ghost_Mode'Pos (G.Ghosts (Id).Mode)));
      end loop;
      for I in Param_Index loop
         Mix (Interfaces.Unsigned_32 (G.Params (I)));
      end loop;
      for Y in Y_Pos loop
         for X in X_Pos loop
            if G.Tiles (X, Y).Pellet or else G.Tiles (X, Y).Power then
               Mix (Interfaces.Unsigned_32 (X) * 32 + Interfaces.Unsigned_32 (Y) + 1);
            end if;
            if G.Tiles (X, Y).Power then
               Mix (16#1000#);
            end if;
         end loop;
      end loop;
      return H;
   end State_Hash;

   function Tile_Code (G : Game; X, Y : Integer) return Natural is
   begin
      if X not in Integer (X_Pos'First) .. Integer (X_Pos'Last)
        or else Y not in Integer (Y_Pos'First) .. Integer (Y_Pos'Last)
      then
         return 0;
      end if;
      if G.Tiles (X_Pos (X), Y_Pos (Y)).Kind = Wall then
         return 0;
      elsif G.Tiles (X_Pos (X), Y_Pos (Y)).Power then
         return 3;
      elsif G.Tiles (X_Pos (X), Y_Pos (Y)).Pellet then
         return 2;
      else
         return 1;
      end if;
   end Tile_Code;

   function Eater_X (G : Game) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return Integer (G.E_X);
   end Eater_X;

   function Eater_Y (G : Game) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return Integer (G.E_Y);
   end Eater_Y;

   function Eater_DX (G : Game) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.E_DX;
   end Eater_DX;

   function Eater_DY (G : Game) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return G.E_DY;
   end Eater_DY;

   function Ghost_X (G : Game; Id : Ghost_Id) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return Integer (G.Ghosts (Id).X);
   end Ghost_X;

   function Ghost_Y (G : Game; Id : Ghost_Id) return Integer is
   begin
      if not G.Started then
         return 0;
      end if;
      return Integer (G.Ghosts (Id).Y);
   end Ghost_Y;

   function Ghost_Mode_Code (G : Game; Id : Ghost_Id) return Natural is
   begin
      if not G.Started then
         return 0;
      end if;
      return Ghost_Mode'Pos (G.Ghosts (Id).Mode);
   end Ghost_Mode_Code;

   function Decision_Of (G : Game; Actor : Natural) return Decision_Code is
   begin
      if not G.Started then
         return None;
      end if;
      if Actor = 0 then
         return G.E_Last.Code;
      elsif Actor in Ghost_Id then
         return G.Ghosts (Actor).Last.Code;
      else
         return None;
      end if;
   end Decision_Of;

   function Host_Started return Boolean is
   begin
      return The_Game.Started;
   end Host_Started;

end Swarm;
