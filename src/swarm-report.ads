-- hunter-swarm-report v1, written into one fixed buffer. The host reads it back
-- a byte at a time. custom holds the side-specific tuning fields (D-017).

package Swarm.Report is

   Max_Stamp    : constant := 80;
   Max_Expected : constant := 160;
   Max_Report   : constant := 196608;

   type Side is (Side_Eater, Side_Ghosts, Side_F9, Side_Crash);
   type Key_Name is (Key_F9, Key_Stop, Key_End, Key_Crash, Key_Level);

   procedure Set_Stamp (Text : String)
   with Pre => Text'Length <= Max_Stamp;

   procedure Set_Stamp_Len (Length : Natural)
   with Pre => Length <= Max_Stamp;

   procedure Set_Stamp_Char (Index : Positive; Code : Natural)
   with Pre => Index <= Max_Stamp and then Code <= 255;

   procedure Set_Expected (Text : String)
   with Pre => Text'Length <= Max_Expected;

   procedure Set_Expected_Len (Length : Natural)
   with Pre => Length <= Max_Expected;

   procedure Set_Expected_Char (Index : Positive; Code : Natural)
   with Pre => Index <= Max_Expected and then Code <= 255;

   procedure Set_Test_Key (Key : Key_Name);

   procedure Build (G : Game; Which : Side);

   function Length return Natural;
   function Byte (Index : Positive) return Character
   with Pre => Index <= Length;

   function Contains (Needle : String) return Boolean;
   function Overflowed return Boolean;

end Swarm.Report;
