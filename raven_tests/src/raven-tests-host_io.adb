with Ada.Strings.Wide_Wide_Unbounded;

package body Raven.Tests.Host_IO is

   use Ada.Strings.Wide_Wide_Unbounded;

   --  A host that keeps what it was given and hands back what it was
   --  told to.  Written and Failed are two places, so a test can say
   --  that an error went to one of them and not to the other.

   type Capture is new IO_Interface with
      record
         Written : Unbounded_Wide_Wide_String;
         Failed  : Unbounded_Wide_Wide_String;
         Reading : Unbounded_Wide_Wide_String;
         Next    : Positive := 1;
      end record;

   overriding procedure Put
     (This : in out Capture;
      Ch   : Wide_Wide_Character);

   overriding procedure Put_Error
     (This : in out Capture;
      Ch   : Wide_Wide_Character);

   overriding procedure Get
     (This      : in out Capture;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean);

   Host : aliased Capture;

   function Written return String
   is (Encode (To_Wide_Wide_String (Host.Written)));

   function Failed return String
   is (Encode (To_Wide_Wide_String (Host.Failed)));

   procedure Give (Text : Wide_Wide_String);

   procedure Test_True
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean);

   procedure Test_String
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   procedure Test_Written
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   procedure Test_Failed
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   ---------
   -- Get --
   ---------

   overriding procedure Get
     (This      : in out Capture;
      Ch        : out Wide_Wide_Character;
      Available : out Boolean)
   is
   begin
      if This.Next > Length (This.Reading) then
         Ch := ' ';
         Available := False;
      else
         Ch := Element (This.Reading, This.Next);
         This.Next := This.Next + 1;
         Available := True;
      end if;
   end Get;

   ----------
   -- Give --
   ----------

   procedure Give (Text : Wide_Wide_String) is
   begin
      Host.Reading := To_Unbounded_Wide_Wide_String (Text);
      Host.Next := 1;
   end Give;

   ---------
   -- Put --
   ---------

   overriding procedure Put
     (This : in out Capture;
      Ch   : Wide_Wide_Character)
   is
   begin
      Append (This.Written, Ch);
   end Put;

   ---------------
   -- Put_Error --
   ---------------

   overriding procedure Put_Error
     (This : in out Capture;
      Ch   : Wide_Wide_Character)
   is
   begin
      Append (This.Failed, Ch);
   end Put_Error;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
      VM : Raven_VM :=
             New_VM (IO           => Host'Access,
                     Library_Path => Library_Path);
   begin
      --  Loading the library writes nothing, so a host that has heard
      --  nothing at all is where this starts.  New_VM took a
      --  Text_Writer and a Read_File_Handler and called neither, so
      --  there was no way to ask it what it had heard.

      Test ("a new VM has written nothing", "", Written);

      Test_Written (VM, "(display ""abc"")", "abc");
      Test_Written (VM, "(write-string ""de"")", "abcde");
      Test_Written (VM, "(write ""f"")", "abcde""f""");
      Test_Written (VM, "(write-char #\g)", "abcde""f""g");

      --  And none of it went to the other place.

      Test ("none of that was an error", "", Failed);

      --  An error port that is somewhere else.  The host had one
      --  place to write before this, so current-error-port was
      --  current-output-port under another name.

      Test_Failed (VM, "(display ""oh"" (current-error-port))", "oh");
      Test_Failed (VM, "(write-char #\! (current-error-port))", "oh!");

      --  Writing an error left what had been written alone.

      Test ("and left the output where it was", "abcde""f""g", Written);

      --  The two are not the same port, and both are output ports.

      Test_True (VM, "(eq? (current-output-port) (current-error-port))",
                 False);
      Test_True (VM, "(output-port? (current-error-port))", True);

      --  Reading.  The host is asked for a character at a time and
      --  says when it has none, which is what the end of the port and
      --  char-ready? are made of.  Nothing could read at all before
      --  ports, and nothing could read from the host but the terminal
      --  before this.

      Give ("hi");
      Test_True (VM, "(char-ready?)", True);

      --  And asking did not eat it.

      Test_True (VM, "(eq? (read-char) #\h)", True);
      Test_True (VM, "(eq? (peek-char) #\i)", True);
      Test_True (VM, "(eq? (read-char) #\i)", True);
      Test_True (VM, "(eof-object? (read-char))", True);

      --  A port at its end is ready too: the read that answers with
      --  the end of it does not wait either.

      Test_True (VM, "(char-ready?)", True);

      --  A line comes from the host the same way, a character at a
      --  time, and stops at the newline.

      Give ("one" & Wide_Wide_Character'Val (10) & "two");
      Test_String (VM, "(read-line)", "one");
      Test_String (VM, "(read-line)", "two");
      Test_True (VM, "(eof-object? (read-line))", True);

      --  And read-string takes what the host has and no more.

      Give ("abcd");
      Test_String (VM, "(read-string 2)", "ab");
      Test_String (VM, "(read-string 9)", "cd");
      Test_True (VM, "(eof-object? (read-string 1))", True);

      --  A port opened on a string is not the host's, and writing to
      --  one tells the host nothing.

      declare
         Before : constant String := Written;
      begin
         VM.Evaluate
           ("(let ((p (open-output-string))) (display ""quiet"" p)"
            & " (get-output-string p))");
         Test ("a string port does not reach the host", Before, Written);
      end;

      VM.Close_VM;
   end Run_Tests;

   -----------------
   -- Test_Failed --
   -----------------

   procedure Test_Failed
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, Expected, Failed);
   end Test_Failed;

   -----------------
   -- Test_String --
   -----------------

   procedure Test_String
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, Expected, VM.Get_Slot (1));
   end Test_String;

   ---------------
   -- Test_True --
   ---------------

   procedure Test_True
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, VM.Get_Slot (1) = Expected);
   end Test_True;

   ------------------
   -- Test_Written --
   ------------------

   procedure Test_Written
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, Expected, Written);
   end Test_Written;

end Raven.Tests.Host_IO;
