with Interfaces;

package body Swarm.Report is

   use type Interfaces.Unsigned_32;

   Buf : String (1 .. Max_Report);
   Len : Natural := 0;
   Too_Big : Boolean := False;

   Stamp : String (1 .. Max_Stamp);
   Stamp_Len : Natural := 0;
   Expected : String (1 .. Max_Expected);
   Expected_Len : Natural := 0;
   Test_Key : Key_Name := Key_F9;

   procedure Add (S : String) is
   begin
      if Too_Big or else S'Length = 0 then
         return;
      end if;
      if Len > Max_Report - S'Length then
         Too_Big := True;
         return;
      end if;
      for C of S loop
         Len := Len + 1;
         Buf (Len) := C;
      end loop;
   end Add;

   procedure Add_Char (C : Character) is
      S : String (1 .. 1);
   begin
      S (1) := C;
      Add (S);
   end Add_Char;

   procedure Add_Nat (N : Natural) is
      Figures : String (1 .. 12);
      V : Natural := N;
      L : Natural := 0;
   begin
      if V = 0 then
         Add ("0");
         return;
      end if;
      while V > 0 loop
         L := L + 1;
         Figures (L) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      for I in reverse 1 .. L loop
         Add_Char (Figures (I));
      end loop;
   end Add_Nat;

   procedure Add_Uns (V : Interfaces.Unsigned_32) is
      Figures : String (1 .. 10);
      N : Interfaces.Unsigned_32 := V;
      L : Natural := 0;
   begin
      if N = 0 then
         Add ("0");
         return;
      end if;
      while N > 0 loop
         L := L + 1;
         Figures (L) :=
           Character'Val (Character'Pos ('0') + Natural (N mod 10));
         N := N / 10;
      end loop;
      for I in reverse 1 .. L loop
         Add_Char (Figures (I));
      end loop;
   end Add_Uns;

   procedure Add_Hex8 (V : Interfaces.Unsigned_32) is
      Hex : constant String := "0123456789abcdef";
      N : Interfaces.Unsigned_32 := V;
      Figures : String (1 .. 8);
   begin
      for I in reverse 1 .. 8 loop
         Figures (I) := Hex (Natural (N mod 16) + 1);
         N := N / 16;
      end loop;
      Add (Figures);
   end Add_Hex8;

   procedure Add_Esc (S : String) is
      Hex : constant String := "0123456789abcdef";
   begin
      for C of S loop
         if C = '"' or else C = '\' then
            Add_Char ('\');
            Add_Char (C);
         elsif C < ' ' then
            Add ("\u00");
            Add_Char (Hex (Character'Pos (C) / 16 + 1));
            Add_Char (Hex (Character'Pos (C) mod 16 + 1));
         else
            Add_Char (C);
         end if;
      end loop;
   end Add_Esc;

   procedure Add_Decision_Name (Code : Decision_Code) is
   begin
      case Code is
         when None => Add ("none");
         when Seek_Pellet => Add ("seek_pellet");
         when Seek_Power => Add ("seek_power");
         when Flee => Add ("flee");
         when Hunt => Add ("hunt");
         when Chase => Add ("chase");
         when Cutoff => Add ("cutoff");
         when Cover => Add ("cover");
         when Ghost_Flee => Add ("ghost_flee");
         when Return_Home => Add ("return_home");
      end case;
   end Add_Decision_Name;

   procedure Add_Event_Name (Code : Event_Code) is
   begin
      case Code is
         when Game_Start => Add ("game_start");
         when Pellet_Eaten => Add ("pellet");
         when Power_Eaten => Add ("power");
         when Death => Add ("death");
         when Catch => Add ("catch");
         when Fright_End => Add ("fright_end");
         when Win => Add ("win");
         when Lose => Add ("lose");
         when Timeout => Add ("timeout");
      end case;
   end Add_Event_Name;

   procedure Add_Outcome (G : Game) is
   begin
      if not Started (G) then
         Add ("ready");
         return;
      end if;
      case Outcome (G) is
         when Running => Add ("running");
         when Won => Add ("won");
         when Lost => Add ("lost");
         when Timed_Out => Add ("timed_out");
      end case;
   end Add_Outcome;

   procedure Add_Key is
   begin
      case Test_Key is
         when Key_F9 => Add ("f9");
         when Key_Stop => Add ("stop");
         when Key_End => Add ("game-end");
         when Key_Crash => Add ("crash");
      end case;
   end Add_Key;

   function Oldest (Next, Count, Dropped : Natural) return Natural is
   begin
      if Count = 0 or else Dropped = 0 then
         return 1;
      else
         return Next;
      end if;
   end Oldest;

   procedure Set_Stamp (Text : String) is
   begin
      Stamp_Len := Text'Length;
      for I in Text'Range loop
         Stamp (I - Text'First + 1) := Text (I);
      end loop;
   end Set_Stamp;

   procedure Set_Stamp_Len (Length : Natural) is
   begin
      Stamp_Len := Length;
   end Set_Stamp_Len;

   procedure Set_Stamp_Char (Index : Positive; Code : Natural) is
   begin
      Stamp (Index) := Character'Val (Code);
   end Set_Stamp_Char;

   procedure Set_Expected (Text : String) is
   begin
      Expected_Len := Text'Length;
      for I in Text'Range loop
         Expected (I - Text'First + 1) := Text (I);
      end loop;
   end Set_Expected;

   procedure Set_Expected_Len (Length : Natural) is
   begin
      Expected_Len := Length;
   end Set_Expected_Len;

   procedure Set_Expected_Char (Index : Positive; Code : Natural) is
   begin
      Expected (Index) := Character'Val (Code);
   end Set_Expected_Char;

   procedure Set_Test_Key (Key : Key_Name) is
   begin
      Test_Key := Key;
   end Set_Test_Key;

   procedure Build (G : Game; Which : Side) is
      Lo : Natural;
      Hi : Natural;

      procedure Add_Decisions is
         Idx : Natural := Oldest (G.Dec_Next, G.Dec_Count, G.Dec_Dropped);
         Seen : Natural := 0;
         First : Boolean := True;
      begin
         while Seen < G.Dec_Count loop
            declare
               Item : Decision renames G.Decs (Idx);
            begin
               if Item.Actor in Lo .. Hi then
                  if not First then
                     Add (",");
                  end if;
                  First := False;
                  Add ("{""tick"":");
                  Add_Nat (Item.Tick);
                  Add (",""actor"":");
                  Add_Nat (Item.Actor);
                  Add (",""code"":""");
                  Add_Decision_Name (Item.Code);
                  Add (""",""x"":");
                  Add_Nat (Natural (Item.X));
                  Add (",""y"":");
                  Add_Nat (Natural (Item.Y));
                  Add ("}");
               end if;
            end;
            Seen := Seen + 1;
            if Idx = Max_Decisions then
               Idx := 1;
            else
               Idx := Idx + 1;
            end if;
         end loop;
      end Add_Decisions;

      procedure Add_Events is
         Idx : Natural := Oldest (G.Ev_Next, G.Ev_Count, G.Ev_Dropped);
         Seen : Natural := 0;
         First : Boolean := True;
      begin
         while Seen < G.Ev_Count loop
            declare
               Item : Event renames G.Evs (Idx);
            begin
               if not First then
                  Add (",");
               end if;
               First := False;
               Add ("{""tick"":");
               Add_Nat (Item.Tick);
               Add (",""code"":""");
               Add_Event_Name (Item.Code);
               Add (""",""a"":");
               if Item.A < 0 then
                  Add ("-");
                  Add_Nat (Natural (-Item.A));
               else
                  Add_Nat (Natural (Item.A));
               end if;
               Add (",""b"":");
               if Item.B < 0 then
                  Add ("-");
                  Add_Nat (Natural (-Item.B));
               else
                  Add_Nat (Natural (Item.B));
               end if;
               Add ("}");
            end;
            Seen := Seen + 1;
            if Idx = Max_Events then
               Idx := 1;
            else
               Idx := Idx + 1;
            end if;
         end loop;
      end Add_Events;

      procedure Add_Settings is
      begin
         Add ("{""danger_radius"":");
         Add_Nat (Natural (Param (G, Danger_Radius)));
         Add (",""power_seek"":");
         Add_Nat (Natural (Param (G, Power_Seek)));
         Add (",""threat_range"":");
         Add_Nat (Natural (Param (G, Threat_Range)));
         Add (",""hunt_range"":");
         Add_Nat (Natural (Param (G, Hunt_Range)));
         Add (",""cutoff_lead"":");
         Add_Nat (Natural (Param (G, Cutoff_Lead)));
         Add (",""role_interval"":");
         Add_Nat (Natural (Param (G, Role_Interval)));
         Add (",""fright_ticks"":");
         Add_Nat (Natural (Param (G, Fright_Ticks)));
         Add (",""starve_ticks"":");
         Add_Nat (Natural (Param (G, Starve_Ticks)));
         Add (",""ghost_stride"":");
         Add_Nat (Natural (Param (G, Ghost_Stride)));
         Add (",""pellet_points"":");
         Add_Nat (Pellet_Points);
         Add (",""power_points"":");
         Add_Nat (Power_Points);
         Add (",""initial_lives"":");
         Add_Nat (Initial_Lives);
         Add (",""respawn_pause"":");
         Add_Nat (Respawn_Pause_Ticks);
         Add (",""tick_cap"":");
         Add_Nat (Tick_Cap);
         Add (",""log_gap"":");
         Add_Nat (Log_Gap);
         Add ("}");
      end Add_Settings;
   begin
      case Which is
         when Side_Eater =>
            Lo := 0;
            Hi := 0;
         when Side_Ghosts =>
            Lo := 1;
            Hi := 4;
         when Side_F9 | Side_Crash =>
            Lo := 0;
            Hi := 4;
      end case;
      Len := 0;
      Too_Big := False;
      Add ("{""schema"":""poncelet-report"",""schema_version"":""v1"",");
      Add ("""stamp"":""");
      if Stamp_Len > 0 then
         Add_Esc (Stamp (1 .. Stamp_Len));
      end if;
      Add (""",""seeds"":{""world"":");
      Add_Uns (G.World_Seed);
      Add (",""ai"":");
      Add_Uns (G.AI_Seed);
      Add ("},""test_key"":""");
      Add_Key;
      Add (""",""expected"":""");
      if Expected_Len > 0 then
         Add_Esc (Expected (1 .. Expected_Len));
      end if;
      Add (""",""action_log"":[");
      Add_Decisions;
      Add ("],""state_hash"":""");
      Add_Hex8 (State_Hash (G));
      Add (""",""events"":[");
      Add_Events;
      Add ("],""events_dropped"":");
      Add_Nat (G.Ev_Dropped);
      Add (",""errors"":[");
      if G.Error_Used then
         Add ("{""kind"":""last_chance"",""file"":"""",""line"":");
         Add_Nat (G.Error_Line);
         Add ("}");
      end if;
      Add ("],""environment"":{""runtime"":""ada"",""checks"":""contracts-in-source"",""wasm_checks"":""gnatp""},");
      Add ("""custom"":{""side"":""");
      case Which is
         when Side_Eater => Add ("eater");
         when Side_Ghosts => Add ("ghost_team");
         when Side_F9 => Add ("full");
         when Side_Crash => Add ("crash");
      end case;
      Add (""",""summary"":""BUILD ");
      if Stamp_Len > 0 then
         Add_Esc (Stamp (1 .. Stamp_Len));
      end if;
      Add ("\nTEST KEY ");
      Add_Key;
      Add ("\nSUMMARY outcome=");
      Add_Outcome (G);
      Add (" score=");
      Add_Nat (Score (G));
      Add (" lives=");
      Add_Nat (Lives (G));
      Add (" deaths=");
      Add_Nat (Deaths (G));
      Add (" catches=");
      Add_Nat (Catches (G));
      Add (" pellets=");
      Add_Nat (Pellets_Left (G));
      Add (" tick=");
      Add_Nat (Tick_Count (G));
      Add (" hash=");
      Add_Hex8 (State_Hash (G));
      Add (""",""settings"":");
      Add_Settings;
      Add (",""score"":");
      Add_Nat (Score (G));
      Add (",""lives"":");
      Add_Nat (Lives (G));
      Add (",""deaths"":");
      Add_Nat (Deaths (G));
      Add (",""catches"":");
      Add_Nat (Catches (G));
      Add (",""pellets_left"":");
      Add_Nat (Pellets_Left (G));
      Add (",""power_left"":");
      Add_Nat (Power_Left (G));
      Add (",""tick"":");
      Add_Nat (Tick_Count (G));
      Add (",""outcome"":""");
      Add_Outcome (G);
      Add (""",""bias"":");
      Add_Nat (G.Bias);
      Add (",""decisions_dropped"":");
      Add_Nat (G.Dec_Dropped);
      Add (",""eater"":{""x"":");
      Add_Nat (Natural (Eater_X (G)));
      Add (",""y"":");
      Add_Nat (Natural (Eater_Y (G)));
      Add (",""dx"":");
      if Eater_DX (G) < 0 then
         Add ("-");
         Add_Nat (Natural (-Eater_DX (G)));
      else
         Add_Nat (Natural (Eater_DX (G)));
      end if;
      Add (",""dy"":");
      if Eater_DY (G) < 0 then
         Add ("-");
         Add_Nat (Natural (-Eater_DY (G)));
      else
         Add_Nat (Natural (Eater_DY (G)));
      end if;
      Add ("},""ghosts"":[");
      for Id in Ghost_Id loop
         if Id > 1 then
            Add (",");
         end if;
         Add ("{""id"":");
         Add_Nat (Id);
         Add (",""x"":");
         Add_Nat (Natural (Ghost_X (G, Id)));
         Add (",""y"":");
         Add_Nat (Natural (Ghost_Y (G, Id)));
         Add (",""mode"":");
         Add_Nat (Ghost_Mode_Code (G, Id));
         Add ("}");
      end loop;
      Add ("]}}");
      pragma Assert (not Too_Big);
      pragma Assert (Len > 2);
      pragma Assert (Buf (1) = '{');
      pragma Assert (Buf (Len) = '}');
   end Build;

   function Length return Natural is (Len);

   function Byte (Index : Positive) return Character is
   begin
      pragma Assert (Index <= Len);
      return Buf (Index);
   end Byte;

   function Contains (Needle : String) return Boolean is
   begin
      if Needle'Length = 0 then
         return True;
      end if;
      if Len < Needle'Length then
         return False;
      end if;
      for I in 1 .. Len - Needle'Length + 1 loop
         if Buf (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Overflowed return Boolean is (Too_Big);

end Swarm.Report;
