with Ada.Strings.Fixed;

package body Raven.Tests.Slots is

   use Ada.Strings, Ada.Strings.Fixed;

   procedure Test_Kind
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Value_Kind);

   procedure Test_Not_A_String
     (VM         : Raven_VM;
      Expression : String);

   --  Asking a slot to be taken apart when it holds something that
   --  cannot be.

   procedure Test_Refuses
     (VM         : Raven_VM;
      Expression : String);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      --  Every kind a program can put in a slot says which it is.

      Test_Kind (VM, "'()", Nil_Kind);
      Test_Kind (VM, "#t", Boolean_Kind);
      Test_Kind (VM, "#f", Boolean_Kind);
      Test_Kind (VM, "1", Integer_Kind);
      Test_Kind (VM, "-1", Integer_Kind);
      Test_Kind (VM, "1.5", Float_Kind);
      Test_Kind (VM, "#\a", Character_Kind);
      Test_Kind (VM, "'a", Symbol_Kind);
      Test_Kind (VM, """a""", String_Kind);
      Test_Kind (VM, "'(1 2)", Pair_Kind);
      Test_Kind (VM, "(vector 1 2)", Vector_Kind);
      Test_Kind (VM, "(bytevector 1 2)", Bytevector_Kind);
      Test_Kind (VM, "(lambda (x) x)", Procedure_Kind);
      Test_Kind (VM, "(eof-object)", Eof_Kind);

      --  A string is a foreign value and says String_Kind, because a
      --  host handed one almost always wants its characters.  A port
      --  is one too and has no such shortcut.

      Test_Kind (VM, "(current-output-port)", Foreign_Kind);
      Test_Kind (VM, "(open-output-string)", Foreign_Kind);

      --  Nil is not false and false is not nil, which a host reading
      --  a boolean cannot otherwise tell: the boolean getter answers
      --  for everything, and says false for both of these.

      Test ("a port is not nil", VM.Kind (1) /= Nil_Kind);
      Test_Kind (VM, "'()", Nil_Kind);
      Test ("nil is not truthy", not Boolean'(VM.Get_Slot (1)));
      Test_Kind (VM, "#f", Boolean_Kind);
      Test ("false is not truthy", not Boolean'(VM.Get_Slot (1)));

      --  Asking a slot for a string when it holds something else used
      --  to answer with a rendering of the something else, so a host
      --  comparing it against a word of its own got a plausible
      --  answer from a value that was never a string.

      Test_Not_A_String (VM, "1");
      Test_Not_A_String (VM, "'a");
      Test_Not_A_String (VM, "'()");
      Test_Not_A_String (VM, "'(1 2)");
      Test_Not_A_String (VM, "(current-output-port)");

      --  And the rendering is still to be had, under a name that says
      --  what it is.  Readable is what the reader would read back,
      --  which is where a string keeps its quotation marks.

      VM.Evaluate ("'(1 2)");
      Test ("a list renders", "(1 2)", VM.Show_Slot (1));

      VM.Evaluate ("""a""");
      Test ("a string written", """a""", VM.Show_Slot (1));
      Test ("a string displayed", "a", VM.Show_Slot (1, Readable => False));

      VM.Evaluate ("'probe-slot-name");
      Test ("a symbol is itself either way",
            VM.Show_Slot (1), VM.Show_Slot (1, Readable => False));

      --  The kinds a slot could carry in neither direction.

      VM.Evaluate ("1.5");
      Test ("a float comes out", "1.50000E+00",
            Trim (Float'Image (Float'(VM.Get_Slot (1))), Left));

      VM.Set_Slot (1, Float'(2.5));
      Test ("and goes in", Float_Kind'Image, VM.Kind (1)'Image);
      Test ("as itself", "2.50000E+00",
            Trim (Float'Image (Float'(VM.Get_Slot (1))), Left));

      VM.Evaluate ("#\a");
      Test ("a character comes out",
            Wide_Wide_Character'(VM.Get_Slot (1)) = 'a');

      VM.Set_Slot (1, Wide_Wide_Character'('z'));
      Test ("and goes in", "#\z", VM.Show_Slot (1));

      VM.Evaluate ("'probe-a-symbol");
      Test ("a symbol's name", "probe-a-symbol", VM.Symbol_Name (1));

      VM.Set_Slot_Symbol (1, "probe-another");
      Test ("and a symbol made of one", Symbol_Kind'Image, VM.Kind (1)'Image);
      Test ("under that name", "probe-another", VM.Symbol_Name (1));

      --  Set_Slot of a String made a symbol, so it was not the
      --  opposite of Get_Slot of one and nothing could answer with a
      --  string at all.

      VM.Set_Slot (1, "probe-text");
      Test ("a string goes in", String_Kind'Image, VM.Kind (1)'Image);
      Test ("and comes out", "probe-text", String'(VM.Get_Slot (1)));

      --  Taking a pair apart, which nothing could do.

      VM.Evaluate ("'(1 2 3)");
      VM.Slot_Car (1, 2);
      Test ("the car of a list", "1",
            Trim (Integer'Image (Integer'(VM.Get_Slot (2))), Left));

      VM.Evaluate ("'(1 2 3)");
      VM.Slot_Cdr (1, 1);
      Test ("and the cdr, into the slot it came from",
            "(2 3)", VM.Show_Slot (1));

      --  Which is how a list is walked: cdr into the same slot until
      --  it is no longer a pair.

      VM.Evaluate ("'(1 2 3 4 5)");

      declare
         Count : Natural := 0;
      begin
         while VM.Kind (1) = Pair_Kind loop
            Count := Count + 1;
            VM.Slot_Cdr (1, 1);
         end loop;

         Test ("a list walked to its end", "5",
               Trim (Natural'Image (Count), Left));
         Test ("ends at nil", Nil_Kind'Image, VM.Kind (1)'Image);
      end;

      VM.Evaluate ("(cons 1 2)");
      VM.Set_Slot (2, Integer'(9));
      VM.Slot_Set_Car (1, 2);
      VM.Slot_Set_Cdr (1, 2);
      Test ("a pair written to", "(9 . 9)", VM.Show_Slot (1));

      --  Vectors and bytevectors, made and read and written.

      VM.Slot_New_Vector (1, 3);
      Test ("a vector made", Vector_Kind'Image, VM.Kind (1)'Image);
      Test ("of that length", "3",
            Trim (Natural'Image (VM.Slot_Vector_Length (1)), Left));
      Test ("of nils", "#(() () ())", VM.Show_Slot (1));

      VM.Set_Slot (2, Integer'(7));
      VM.Slot_Set_Vector_Element (1, 1, 2);
      Test ("written into", "#(() 7 ())", VM.Show_Slot (1));

      VM.Slot_Vector_Element (1, 1, 3);
      Test ("and read back", "7",
            Trim (Integer'Image (Integer'(VM.Get_Slot (3))), Left));

      VM.Slot_New_Bytevector (1, 2);
      Test ("a bytevector made", Bytevector_Kind'Image, VM.Kind (1)'Image);
      Test ("of that length", "2",
            Trim (Natural'Image (VM.Slot_Bytevector_Length (1)), Left));

      VM.Slot_Set_Bytevector_Element (1, 0, 255);
      Test ("a byte written", "255",
            Trim (Natural'Image (VM.Slot_Bytevector_Element (1, 0)), Left));
      Test ("and shown", "#u8(255 0)", VM.Show_Slot (1));

      --  Only a byte goes into one, which is what tells it from a
      --  vector, and this is a way in that did not exist before.

      declare
         Refused : Boolean := False;
      begin
         VM.Slot_Set_Bytevector_Element (1, 0, 256);
      exception
         when Constraint_Error =>
            Refused := True;
            Test ("256 is not a byte", Refused);
      end;

      --  equal? walks what it is given.  A host had the equality Ada
      --  gives a private type, which is eq?.

      VM.Evaluate ("(list 1 (list 2 3))");
      VM.Set_Slot (2, Object'(VM.Get_Slot (1)));
      VM.Evaluate ("(list 1 (list 2 3))");

      Test ("two lists of the same things are equal",
            VM.Slot_Equal (1, 2));
      Test ("and are not the same list",
            VM.Get_Slot (1) /= Object'(VM.Get_Slot (2)));

      VM.Evaluate ("(list 1 (list 2 4))");
      Test ("two that differ are not", not VM.Slot_Equal (1, 2));

      --  And each of these refuses a slot holding the wrong thing,
      --  the way the string one does.

      Test_Refuses (VM, "1");
      Test_Refuses (VM, "'a");
      Test_Refuses (VM, "'()");
   end Run_Tests;

   ---------------
   -- Test_Kind --
   ---------------

   procedure Test_Kind
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Value_Kind)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression & " is a " & Value_Kind'Image (Expected),
            Value_Kind'Image (Expected),
            Value_Kind'Image (VM.Kind (1)));
   end Test_Kind;

   ------------------
   -- Test_Refuses --
   ------------------

   procedure Test_Refuses
     (VM         : Raven_VM;
      Expression : String)
   is
      Refused : Natural := 0;
   begin
      VM.Evaluate (Expression);

      begin
         VM.Slot_Car (1, 2);
      exception
         when Constraint_Error =>
            Refused := Refused + 1;
      end;

      begin
         Refused := Refused + VM.Slot_Vector_Length (1);
      exception
         when Constraint_Error =>
            Refused := Refused + 1;
      end;

      Test (Expression & " is neither a pair nor a vector",
            "2", Trim (Natural'Image (Refused), Left));
   end Test_Refuses;

   -----------------------
   -- Test_Not_A_String --
   -----------------------

   procedure Test_Not_A_String
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);

      declare
         Answer : constant String := VM.Get_Slot (1);
      begin
         Test (Expression & " is not a string", "refused", Answer);
      end;
   exception
      when Constraint_Error =>
         Test (Expression & " is not a string", "refused", "refused");
   end Test_Not_A_String;

end Raven.Tests.Slots;
