package body Raven.Tests.Slots is

   procedure Test_Kind
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Value_Kind);

   procedure Test_Not_A_String
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
