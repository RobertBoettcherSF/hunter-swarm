-- Integer host ABI. Names are what wasm-ld exports. The browser does not
-- pass records or strings; stamp and expected arrive one character at a time.

with Interfaces;

package Swarm.API is

   function Get_Width return Integer
   with Export, Convention => C, External_Name => "hs_width";

   function Get_Height return Integer
   with Export, Convention => C, External_Name => "hs_height";

   function Get_Param_Count return Integer
   with Export, Convention => C, External_Name => "hs_param_count";

   function Get_Param (Index : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_param";

   function Get_Param_Min (Index : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_param_min";

   function Get_Param_Max (Index : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_param_max";

   function Set_Param (Index, Value : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_set_param";

   procedure Start (World_Seed, AI_Seed : Interfaces.Unsigned_32)
   with Export, Convention => C, External_Name => "hs_start";

   function Do_Tick return Integer
   with Export, Convention => C, External_Name => "hs_tick";

   function Get_Started return Integer
   with Export, Convention => C, External_Name => "hs_started";

   function Get_Outcome return Integer
   with Export, Convention => C, External_Name => "hs_outcome";

   function Get_Score return Integer
   with Export, Convention => C, External_Name => "hs_score";

   function Get_Lives return Integer
   with Export, Convention => C, External_Name => "hs_lives";

   function Get_Deaths return Integer
   with Export, Convention => C, External_Name => "hs_deaths";

   function Get_Catches return Integer
   with Export, Convention => C, External_Name => "hs_catches";

   function Get_Tick_Count return Integer
   with Export, Convention => C, External_Name => "hs_tick_count";

   function Get_Pellets return Integer
   with Export, Convention => C, External_Name => "hs_pellets";

   function Get_Power return Integer
   with Export, Convention => C, External_Name => "hs_power";

   function Get_Hash return Interfaces.Unsigned_32
   with Export, Convention => C, External_Name => "hs_hash";

   function Get_Tile (X, Y : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_tile";

   function Get_Eater_X return Integer
   with Export, Convention => C, External_Name => "hs_eater_x";

   function Get_Eater_Y return Integer
   with Export, Convention => C, External_Name => "hs_eater_y";

   function Get_Eater_DX return Integer
   with Export, Convention => C, External_Name => "hs_eater_dx";

   function Get_Eater_DY return Integer
   with Export, Convention => C, External_Name => "hs_eater_dy";

   function Get_Ghost_X (Id : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_ghost_x";

   function Get_Ghost_Y (Id : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_ghost_y";

   function Get_Ghost_Mode (Id : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_ghost_mode";

   function Get_Decision (Actor : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_decision";

   procedure Set_Stamp_Len (Length : Integer)
   with Export, Convention => C, External_Name => "hs_set_stamp_len";

   procedure Set_Stamp_Char (Index, Code : Integer)
   with Export, Convention => C, External_Name => "hs_set_stamp_char";

   procedure Set_Expected_Len (Length : Integer)
   with Export, Convention => C, External_Name => "hs_set_expected_len";

   procedure Set_Expected_Char (Index, Code : Integer)
   with Export, Convention => C, External_Name => "hs_set_expected_char";

   procedure Set_Test_Key (Key : Integer)
   with Export, Convention => C, External_Name => "hs_set_test_key";

   procedure Build_Report (Which : Integer)
   with Export, Convention => C, External_Name => "hs_build_report";

   function Report_Len return Integer
   with Export, Convention => C, External_Name => "hs_report_len";

   function Report_Byte (Index : Integer) return Integer
   with Export, Convention => C, External_Name => "hs_report_byte";

end Swarm.API;
