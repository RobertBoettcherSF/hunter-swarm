with Swarm.Report;

package body Swarm.API is

   function Get_Width return Integer is (Width);
   function Get_Height return Integer is (Height);
   function Get_Param_Count return Integer is (Param_Count);

   function Get_Param (Index : Integer) return Integer is
   begin
      return Param (The_Game, Index);
   end Get_Param;

   function Get_Param_Min (Index : Integer) return Integer is
     (Param_Min (Index));

   function Get_Param_Max (Index : Integer) return Integer is
     (Param_Max (Index));

   function Set_Param (Index, Value : Integer) return Integer is
      OK : Boolean;
   begin
      Swarm.Set_Param (The_Game, Index, Value, OK);
      if OK then
         return 1;
      else
         return 0;
      end if;
   end Set_Param;

   procedure Start (Grid_Seed, Eater_Seed, Ghost_Seed : Interfaces.Unsigned_32) is
   begin
      Swarm.Start (The_Game, Grid_Seed, Eater_Seed, Ghost_Seed);
   end Start;

   function Do_Tick return Integer is
   begin
      Tick (The_Game);
      return Outcome_Kind'Pos (Outcome (The_Game));
   end Do_Tick;

   function Get_Started return Integer is
   begin
      if Started (The_Game) then
         return 1;
      else
         return 0;
      end if;
   end Get_Started;

   function Get_Outcome return Integer is
     (Outcome_Kind'Pos (Outcome (The_Game)));

   function Get_Score return Integer is (Score (The_Game));
   function Get_Lives return Integer is (Lives (The_Game));
   function Get_Deaths return Integer is (Deaths (The_Game));
   function Get_Catches return Integer is (Catches (The_Game));
   function Get_Tick_Count return Integer is (Tick_Count (The_Game));
   function Get_Pellets return Integer is (Pellets_Left (The_Game));
   function Get_Power return Integer is (Power_Left (The_Game));

   function Get_Hash return Interfaces.Unsigned_32 is
     (State_Hash (The_Game));

   function Get_Tile (X, Y : Integer) return Integer is
     (Integer (Tile_Code (The_Game, X, Y)));

   function Get_Eater_X return Integer is (Eater_X (The_Game));
   function Get_Eater_Y return Integer is (Eater_Y (The_Game));
   function Get_Eater_DX return Integer is (Eater_DX (The_Game));
   function Get_Eater_DY return Integer is (Eater_DY (The_Game));

   function Get_Ghost_X (Id : Integer) return Integer is
   begin
      if Id not in Ghost_Id then
         return 0;
      end if;
      return Ghost_X (The_Game, Id);
   end Get_Ghost_X;

   function Get_Ghost_Y (Id : Integer) return Integer is
   begin
      if Id not in Ghost_Id then
         return 0;
      end if;
      return Ghost_Y (The_Game, Id);
   end Get_Ghost_Y;

   function Get_Ghost_Mode (Id : Integer) return Integer is
   begin
      if Id not in Ghost_Id then
         return 0;
      end if;
      return Integer (Ghost_Mode_Code (The_Game, Id));
   end Get_Ghost_Mode;

   function Get_Decision (Actor : Integer) return Integer is
   begin
      if Actor < 0 then
         return 0;
      end if;
      return Decision_Code'Pos (Decision_Of (The_Game, Natural (Actor)));
   end Get_Decision;

   procedure Set_Stamp_Len (Length : Integer) is
   begin
      if Length < 0 or else Length > Report.Max_Stamp then
         return;
      end if;
      Report.Set_Stamp_Len (Length);
   end Set_Stamp_Len;

   procedure Set_Stamp_Char (Index, Code : Integer) is
   begin
      if Index < 1 or else Index > Report.Max_Stamp then
         return;
      end if;
      if Code < 0 or else Code > 255 then
         return;
      end if;
      Report.Set_Stamp_Char (Index, Code);
   end Set_Stamp_Char;

   procedure Set_Expected_Len (Length : Integer) is
   begin
      if Length < 0 or else Length > Report.Max_Expected then
         return;
      end if;
      Report.Set_Expected_Len (Length);
   end Set_Expected_Len;

   procedure Set_Expected_Char (Index, Code : Integer) is
   begin
      if Index < 1 or else Index > Report.Max_Expected then
         return;
      end if;
      if Code < 0 or else Code > 255 then
         return;
      end if;
      Report.Set_Expected_Char (Index, Code);
   end Set_Expected_Char;

   procedure Set_Test_Key (Key : Integer) is
   begin
      case Key is
         when 0 => Report.Set_Test_Key (Report.Key_F9);
         when 1 => Report.Set_Test_Key (Report.Key_Stop);
         when 2 => Report.Set_Test_Key (Report.Key_End);
         when 3 => Report.Set_Test_Key (Report.Key_Crash);
         when others =>
            null;
      end case;
   end Set_Test_Key;

   procedure Build_Report (Which : Integer) is
   begin
      case Which is
         when 0 => Report.Build (The_Game, Report.Side_Eater);
         when 1 => Report.Build (The_Game, Report.Side_Ghosts);
         when 2 => Report.Build (The_Game, Report.Side_F9);
         when 3 => Report.Build (The_Game, Report.Side_Crash);
         when others =>
            null;
      end case;
   end Build_Report;

   function Report_Len return Integer is (Report.Length);

   function Report_Byte (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Report.Length then
         return 0;
      end if;
      return Character'Pos (Report.Byte (Index));
   end Report_Byte;

end Swarm.API;
