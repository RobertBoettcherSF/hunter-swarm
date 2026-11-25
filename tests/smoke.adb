with Ada.Text_IO;
with Interfaces;
with Swarm.API;
with Swarm.Report;

procedure Smoke is
   use type Interfaces.Unsigned_32;
   use type Swarm.Outcome_Kind;

   procedure Need (Needle : String) is
   begin
      pragma Assert (Swarm.Report.Contains (Needle));
   end Need;

   function Braces_Match return Boolean is
      Open_N : Natural := 0;
      Close_N : Natural := 0;
   begin
      for I in 1 .. Swarm.Report.Length loop
         if Swarm.Report.Byte (I) = '{' then
            Open_N := Open_N + 1;
         elsif Swarm.Report.Byte (I) = '}' then
            Close_N := Close_N + 1;
         end if;
      end loop;
      return Open_N > 0 and then Open_N = Close_N;
   end Braces_Match;

   G : Swarm.Game;
   OK : Boolean;
   H1, H2 : Interfaces.Unsigned_32;
begin
   Swarm.Set_Param (G, Swarm.Danger_Radius, 3, OK);
   pragma Assert (OK);
   pragma Assert (Swarm.Param (G, Swarm.Danger_Radius) = 3);
   Swarm.Set_Param (G, Swarm.Danger_Radius, 0, OK);
   pragma Assert (not OK);
   pragma Assert (Swarm.Param (G, Swarm.Danger_Radius) = 3);
   pragma Assert (Swarm.Param_Min (Swarm.Ghost_Stride) = 1);
   pragma Assert (Swarm.Param_Max (Swarm.Ghost_Stride) = 4);
   pragma Assert (Swarm.Param_Min (99) = 0);

   Swarm.Start (G, 0, 1, 1);
   pragma Assert (Swarm.Started (G));
   pragma Assert (Swarm.Pellets_Left (G) = 193);
   pragma Assert (Swarm.Lives (G) = 5);
   pragma Assert (Swarm.Tile_Code (G, Swarm.Eater_X (G), Swarm.Eater_Y (G)) /= 0);
   pragma Assert (Swarm.Tile_Code (G, -1, 0) = 0);
   for I in 1 .. 40 loop
      Swarm.Tick (G);
   end loop;
   H1 := Swarm.State_Hash (G);
   Swarm.Start (G, 0, 1, 1);
   for I in 1 .. 40 loop
      Swarm.Tick (G);
   end loop;
   H2 := Swarm.State_Hash (G);
   pragma Assert (H1 = H2);

   Swarm.Start (G, 0, 1, 2);
   while Swarm.Outcome (G) = Swarm.Running loop
      Swarm.Tick (G);
   end loop;
   pragma Assert (Swarm.Outcome (G) /= Swarm.Running);
   pragma Assert (Swarm.Tick_Count (G) > 0);
   pragma Assert (Swarm.Tick_Count (G) <= 4000);
   Ada.Text_IO.Put_Line
     ("seed 1 2 " & Swarm.Outcome (G)'Image
      & " score" & Swarm.Score (G)'Image
      & " tick" & Swarm.Tick_Count (G)'Image
      & " deaths" & Swarm.Deaths (G)'Image
      & " pellets" & Swarm.Pellets_Left (G)'Image);

   Swarm.Report.Set_Stamp ("v0.1 b00000000-0000 smoke");
   Swarm.Report.Set_Expected ("smoke run");
   Swarm.Report.Set_Test_Key (Swarm.Report.Key_End);
   Swarm.Report.Build (G, Swarm.Report.Side_F9);
   pragma Assert (not Swarm.Report.Overflowed);
   pragma Assert (Braces_Match);
   Need ("hunter-swarm-report");
   Need ("""schema_version"":""v1""");
   Need ("""seeds""");
   Need ("""grid"":0");
   Need ("""eater"":1");
   Need ("""ghosts"":2");
   Need ("""why_died""");
   Need ("""test_key"":""game-end""");
   Need ("""expected"":""smoke run""");
   Need ("""action_log""");
   Need ("""state_hash""");
   Need ("""events""");
   Need ("""events_dropped""");
   Need ("""errors""");
   Need ("""environment""");
   Need ("""custom""");
   Need ("BUILD ");
   Need ("TEST KEY game-end");
   Need ("SUMMARY outcome=");
   Swarm.Report.Build (G, Swarm.Report.Side_Eater);
   Need ("""side"":""eater""");
   Swarm.Report.Build (G, Swarm.Report.Side_Ghosts);
   Need ("""side"":""ghost_team""");
   pragma Assert (Swarm.Report.Length > 100);
   Ada.Text_IO.Put_Line
     ("eater " & Swarm.Decision_Of (G, 0)'Image
      & " ghost" & Swarm.Ghost_X (G, 1)'Image);

   pragma Assert (Swarm.API.Set_Param (Swarm.Danger_Radius, 2) = 1);
   Swarm.API.Start (0, 7, 1);
   Swarm.Start (G, 1, 3, 1);
   Swarm.Start (G, 2, 3, 1);
   pragma Assert (Swarm.Pellets_Left (G) > 0);
   pragma Assert (Swarm.Host_Started);
   pragma Assert (Swarm.API.Do_Tick >= 0);
   Swarm.API.Set_Test_Key (2);
   Swarm.API.Set_Stamp_Len (4);
   Swarm.API.Set_Stamp_Char (1, Character'Pos ('t'));
   Swarm.API.Set_Stamp_Char (2, Character'Pos ('e'));
   Swarm.API.Set_Stamp_Char (3, Character'Pos ('s'));
   Swarm.API.Set_Stamp_Char (4, Character'Pos ('t'));
   Swarm.API.Set_Expected_Len (1);
   Swarm.API.Set_Expected_Char (1, Character'Pos ('x'));
   Swarm.API.Build_Report (2);
   pragma Assert (Swarm.API.Report_Len > 50);
   pragma Assert (Swarm.API.Report_Byte (1) = Character'Pos ('{'));
   pragma Assert (Swarm.API.Get_Width = Swarm.Width);
   pragma Assert (Swarm.API.Get_Height = Swarm.Height);
   pragma Assert (Swarm.API.Get_Param_Count = Swarm.Param_Count);
   pragma Assert (Swarm.API.Get_Started = 1);

   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, "obj/native/sample-report.json");
      for I in 1 .. Swarm.Report.Length loop
         Ada.Text_IO.Put (File, Swarm.Report.Byte (I));
      end loop;
      Ada.Text_IO.Close (File);
   end;
   Ada.Text_IO.Put_Line ("smoke ok");
end Smoke;
