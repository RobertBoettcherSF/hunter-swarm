with Interfaces;
with System.Storage_Elements;
with Swarm.Report;

procedure Swarm.Last_Chance (Msg : System.Address; Line : Integer) is

   procedure Host_Crash (File_Addr : Interfaces.Unsigned_32; Line_No : Integer)
   with Import, Convention => C, External_Name => "hs_host_crash", No_Return;

   use System.Storage_Elements;
   A : constant Integer_Address := To_Integer (Msg);
begin
   if not The_Game.Error_Used then
      The_Game.Error_Used := True;
      if Line > 0 then
         The_Game.Error_Line := Natural (Line);
      else
         The_Game.Error_Line := 0;
      end if;
      Report.Set_Test_Key (Report.Key_Crash);
      Report.Build (The_Game, Report.Side_Crash); -- reads the game, writes the report buffer
   end if;
   Host_Crash (Interfaces.Unsigned_32 (A), Line);
end Swarm.Last_Chance;
