with Ada.Exceptions;
with Ada.Strings.Fixed;

with Probe_Host;

package body Raven.Tests.Foreign is

   --  A box: a foreign value whose whole content is one object of the
   --  program's.  It is the smallest thing that cannot work unless
   --  the collector is told what a foreign value holds.

   type Box is new Foreign_Value_Instance with
      record
         Held : Object;
      end record;

   overriding function Show
     (This        : Box;
      Show_Object : not null access function (X : Object) return String)
      return String;

   --  How many boxes the collector has given back, which is how a
   --  test can see that letting go of a handle let go of what it
   --  named.  Nothing else can: an object that has been collected
   --  says nothing about it.

   Freed : Natural := 0;

   overriding procedure Free (This : in out Box);

   --  Two boxes are equal when what they hold is: equal?, not eq?, on
   --  the object inside, which is what the machine hands Equal to ask.

   overriding function Equal
     (This         : Box;
      To           : Box;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean
   is (Equal_Object (This.Held, To.Held));

   overriding procedure Mark
     (This    : in out Box;
      Process : not null access procedure (Value : in out Object));

   procedure Make_Box (VM : Raven_VM);
   procedure Open_Box (VM : Raven_VM);

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   ----------
   -- Free --
   ----------

   overriding procedure Free (This : in out Box) is
      pragma Unreferenced (This);
   begin
      Freed := Freed + 1;
   end Free;

   --------------
   -- Make_Box --
   --------------

   procedure Make_Box (VM : Raven_VM) is
      Held : constant Object := VM.Get_Slot (1);
   begin
      VM.Set_Slot
        (1, VM.Create_Foreign_Value (Box'(Foreign_Value_Instance with Held)));
   end Make_Box;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Box;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      --  In out, because being told is not enough: the collector
      --  moves what it copies, so what this holds is somewhere else
      --  afterwards and has to be written back.

      Process (This.Held);
   end Mark;

   --------------
   -- Open_Box --
   --------------

   procedure Open_Box (VM : Raven_VM) is
      Value : constant Foreign_Value_Instance'Class :=
                VM.To_Foreign_Value (VM.Get_Slot (1));
   begin
      if Value not in Box'Class then
         raise Constraint_Error with "probe-unbox: not a box";
      end if;

      VM.Set_Slot (1, Box'Class (Value).Held);
   end Open_Box;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      --  A foreign value written outside raven, using nothing but
      --  what a host can see.  Every suite here is a child of Raven
      --  and sees its private part, so none of them could say whether
      --  the public interface is enough to write one with: this one
      --  is a root unit, and stops compiling if anything it needs
      --  stops being public.

      Probe_Host.Bind (VM);

      VM.Bind_Foreign_Function ("probe-box", Make_Box'Access, 1);
      VM.Bind_Foreign_Function ("probe-unbox", Open_Box'Access, 1);

      --  What goes in comes out, before anything has had a chance to
      --  move.

      Test_Value (VM, "(probe-unbox (probe-box 7))", "7");
      Test_Value (VM, "(car (probe-unbox (probe-box (cons 1 2))))", "1");

      --  The box holds the only reference to that pair, so if the
      --  collector is not told, nothing keeps it and its cell is
      --  given to something else.  And even were something else
      --  holding it, the copy in the box would name the half of the
      --  heap that has just been abandoned.

      VM.Evaluate ("(define probe-kept (probe-box (cons 1 2)))");
      VM.Evaluate ("(vector-churn 3000)");

      Test_Value (VM, "(car (probe-unbox probe-kept))", "1");
      Test_Value (VM, "(cdr (probe-unbox probe-kept))", "2");

      --  A box reached only through another box.  The inner one is
      --  named by nothing but the outer, so it is marked only if
      --  tracing the outer reaches it -- and it must be marked before
      --  the sweep that frees what is unmarked, which runs after the
      --  scan rather than during it.

      VM.Evaluate
        ("(define probe-nested (probe-box (probe-box (cons 3 4))))");
      VM.Evaluate ("(vector-churn 3000)");

      Test_Value
        (VM, "(car (probe-unbox (probe-unbox probe-nested)))", "3");

      --  A box that can be reached from what it holds.  Tracing it
      --  reaches the pair, the pair's car is the box again, and the
      --  flag is what stops that: it is set before what it holds is
      --  handed over, so coming back finds it already marked.

      VM.Evaluate ("(define probe-loop (probe-box (cons '() 5)))");
      VM.Evaluate ("(set-car! (probe-unbox probe-loop) probe-loop)");
      VM.Evaluate ("(vector-churn 3000)");

      Test_Value (VM, "(cdr (probe-unbox probe-loop))", "5");
      Test_Value
        (VM,
         "(cdr (probe-unbox (car (probe-unbox probe-loop))))",
         "5");

      --  And a box that nothing names is still freed: the flag is
      --  cleared at the start of every collection, so being marked
      --  once does not keep it for good.

      Test_Value (VM, "(begin (probe-box (cons 6 7)) 'made)", "made");
      VM.Evaluate ("(vector-churn 3000)");
      Test_Value (VM, "(car (probe-unbox probe-kept))", "1");

      --  What a host outside raven can do with the same mechanism.
      --  It holds two objects, hands both to the collector, and is
      --  still holding them after three thousand collections.

      Test_Value (VM, "(probe-left (probe-couple 1 2))", "1");
      Test_Value (VM, "(probe-right (probe-couple 1 2))", "2");

      VM.Evaluate
        ("(define probe-pair (probe-couple (cons 8 9) (cons 6 7)))");
      VM.Evaluate ("(vector-churn 3000)");

      Test_Value (VM, "(car (probe-left probe-pair))", "8");
      Test_Value (VM, "(cdr (probe-right probe-pair))", "7");

      --  The couple is written on Raven.Foreign_Values, so what is
      --  tested here is the generic as a host uses it: the membership
      --  test it does once, the four it forwards to, and Free reaching
      --  the host's own memory.

      Test_Value (VM, "(probe-couple? (probe-couple 1 2))", "#t");
      Test_Value (VM, "(probe-couple? (probe-box 1))", "#f");
      Test_Value (VM, "(probe-couple? 5)", "#f");
      Test_Value (VM, "(probe-couple 1 (list 2 3))", "#<couple 1 (2 3)>");
      Test_Value
        (VM, "(equal? (probe-couple 1 (list 2)) (probe-couple 1 (list 2)))",
         "#t");
      Test_Value
        (VM, "(equal? (probe-couple 1 (list 2)) (probe-couple 1 (list 3)))",
         "#f");

      declare
         Refused : Boolean := False;
      begin
         begin
            VM.Evaluate ("(probe-left (probe-box 1))");
         exception
            when E : Constraint_Error =>
               Refused :=
                 Ada.Strings.Fixed.Index
                   (Ada.Exceptions.Exception_Message (E),
                    "which is not a value of this kind") > 0;
         end;

         Test ("a couple's accessor refuses a box, and says so", Refused);
      end;

      --  A host calling a procedure it has been handed.  From inside
      --  a foreign function first, which is where a callback is: the
      --  machine is part way through the program that called it, and
      --  has to be where it was afterwards -- the pending addition, the
      --  local it closes over, the value computed before the call.

      Test_Value (VM, "(probe-apply (lambda (x) (* x 2)) 21)", "42");
      Test_Value (VM, "(+ 1 (probe-apply (lambda (x) (* x 10)) 4))", "41");
      Test_Value
        (VM, "(let ((a 5)) (+ a (probe-apply (lambda (x) (+ x a)) 1) a))",
         "16");
      Test_Value (VM, "(probe-apply2 (lambda (x y) (- x y)) 10 3)", "7");
      Test_Value (VM, "(probe-apply2 < 1 2)", "#t");
      Test_Value (VM, "(probe-apply raven-string-length ""abc"")", "3");

      --  A callback that calls back, which is a run inside a run inside
      --  a run.

      Test_Value
        (VM, "(probe-apply (lambda (x)"
         & " (probe-apply (lambda (y) (* y y)) x)) 7)",
         "49");

      --  A collection in the middle of one, with the arguments, the
      --  answer and what the outer program was holding all moved.

      Test_Value
        (VM, "(probe-apply (lambda (x) (vector-churn 3000) x) (list 1 2))",
         "(1 2)");
      Test_Value
        (VM, "(let ((keep (list 7 8)))"
         & " (probe-apply (lambda (x) (vector-churn 3000) x) 0) keep)",
         "(7 8)");

      --  What goes wrong in one is raised out of it, and the machine is
      --  put back first: a host that handles it goes on, and so does the
      --  program that called the host.

      Test_Value
        (VM, "(list 1 (probe-try (lambda (x) (car x)) 5) 3)", "(1 failed 3)");
      Test_Value (VM, "(list 1 (probe-try (lambda (x) x) 2) 3)", "(1 2 3)");

      --  A continuation inside a callback is a continuation like any
      --  other; one made outside it is refused inside it, because the
      --  callback is a run of its own (#47) and the outer run's
      --  registers are no place for it to go on from.

      Test_Value
        (VM, "(probe-apply (lambda (x) (call/cc (lambda (k) (+ 1 (k x))))) 5)",
         "5");
      Test_Value
        (VM, "(list 1 (probe-try (lambda (x) (x 2))"
         & " (call/cc (lambda (k) k))) 3)",
         "(1 failed 3)");

      --  And from outside the machine, where a host holds a procedure it
      --  kept and has nothing running.  Every slot but the answer's is
      --  as the host left it.

      VM.Evaluate ("(lambda (x y) (vector-churn 300) (+ x y))");
      VM.Set_Slot (2, Integer'(20));
      VM.Set_Slot (3, Integer'(22));
      VM.Set_Slot (4, Integer'(99));
      VM.Slot_Apply (1, 2);
      Test ("a host applies a procedure", VM.Show_Slot (1) = "42");
      Test ("and its arguments are where it left them",
            VM.Show_Slot (2) = "20" and then VM.Show_Slot (3) = "22");
      Test ("and so is a slot it was not using", VM.Show_Slot (4) = "99");

      declare
         Refused : Boolean := False;
      begin
         VM.Set_Slot (1, Integer'(5));
         begin
            VM.Slot_Apply (1, 0);
         exception
            when Constraint_Error =>
               Refused := True;
         end;
         Test ("applying what is not a procedure is refused", Refused);
      end;

      declare
         Before : constant Natural := Probe_Host.Couples_Freed;
      begin
         VM.Evaluate ("(set! probe-pair #f)");

         for Index in Slot_Index loop
            VM.Set_Slot_Nil (Index);
         end loop;

         VM.Evaluate ("(vector-churn 3000)");
         Test ("a couple nothing names is given back to the host",
               Probe_Host.Couples_Freed > Before);
      end;

      --  Closing a VM tells its foreign values.  No collection
      --  happens at shutdown, and Free is how one gives back what it
      --  stood for -- an open file, a host's memory -- so without
      --  this a port stayed open for the life of the process.

      declare
         Before : constant Natural := Freed;
         Other  : Raven_VM := New_VM (Library_Path => Library_Path);
         Used   : Boolean := False;
      begin
         Other.Bind_Foreign_Function ("probe-box", Make_Box'Access, 1);
         Other.Evaluate ("(import (scheme base))");
         Other.Evaluate ("(define probe-shut (probe-box 1))");

         Test ("a box of another VM's is not freed while it lives",
               Before = Freed);

         Other.Close_VM;
         Test ("and is freed when that VM closes", Before + 1 = Freed);

         --  A host with a cleanup path reaches here twice and should
         --  not have to remember which time it is.

         Other.Close_VM;
         Test ("closing a closed VM does nothing", Before + 1 = Freed);

         --  And using one afterwards is caught rather than reading
         --  memory that has been given back.

         Used := True;

         begin
            Other.Evaluate ("1");
         exception
            when others =>
               Used := False;
         end;

         Test ("using a closed VM is refused", not Used);
      end;

      --  A handle on what is in a slot.  A slot holds what a foreign
      --  function was given only until the machine runs again, so a
      --  handle is how a host keeps one -- and it used to answer with
      --  nothing at all, so the only handle to be had was on a name.

      VM.Evaluate ("(cons 11 22)");

      declare
         Held : Handle := VM.Get_Slot (1);
      begin
         Test ("a handle on a slot is a handle", not Is_Null (Held));

         --  Nothing else names that pair now, and the collector runs
         --  a great many times before it is asked for again.  It has
         --  to be kept, and it has to be moved with everything else:
         --  a root that is not updated is worse than none.

         VM.Set_Slot_Nil (1);
         VM.Evaluate ("(vector-churn 3000)");
         VM.Set_Slot (1, Held);

         Test ("and what it names survives a collection",
               "(11 . 22)", Encode (VM.Display (VM.Get_Slot (1))));

         VM.Release (Held);
         Test ("a released handle is null", Is_Null (Held));
      end;

      --  And letting go of one lets go of what it named.  A box says
      --  when it is collected, which is the only way to watch this
      --  from outside.

      declare
         Before : constant Natural := Freed;
      begin
         VM.Evaluate ("(probe-box 99)");

         declare
            Held : Handle := VM.Get_Slot (1);
         begin
            for Index in Slot_Index loop
               VM.Set_Slot_Nil (Index);
            end loop;

            VM.Evaluate ("(vector-churn 3000)");
            Test ("a box a handle names is not collected", Before = Freed);

            VM.Release (Held);

            for Index in Slot_Index loop
               VM.Set_Slot_Nil (Index);
            end loop;

            VM.Evaluate ("(vector-churn 3000)");
            Test ("and is collected once the handle goes",
                  Before + 1 = Freed);
         end;
      end;

      --  The collector sweeps the values there are rather than every
      --  id there has been, and still finds every one it should: more
      --  boxes than the old ceiling on foreign values, all live at
      --  once, and then all of them freed.

      declare
         Before : constant Natural := Freed;
      begin
         VM.Evaluate
           ("(define (probe-boxes v n)"
            & " (if (= n 0) v"
            & " (begin (vector-set! v (- n 1) (probe-box n))"
            & " (probe-boxes v (- n 1)))))");
         VM.Evaluate
           ("(vector-length (probe-boxes (make-vector 10500 #f) 10500))");
         Test ("more boxes than there were foreign values",
               VM.Show_Slot (1) = "10500");

         for Index in Slot_Index loop
            VM.Set_Slot_Nil (Index);
         end loop;

         VM.Evaluate ("(vector-churn 3000)");
         Test ("and every one of them is freed", Before + 10_500 = Freed);
      end;

      --  What a box holds, shown and compared.  Show and Equal were
      --  given nothing of the machine's, so a box showed as #box
      --  whatever was in it and compared by the word it held: two
      --  boxes of equal lists were not equal?, and equal? stopped at
      --  a box in the middle of anything it walked.

      Test_Value (VM, "(probe-box (list 1 2))", "#<box (1 2)>");
      Test_Value (VM, "(probe-box (probe-box 'a))", "#<box #<box a>>");
      Test_Value (VM, "(raven-write-text (probe-box ""hi""))",
                  """#<box \""hi\"">""");
      Test_Value (VM, "(raven-display-text (probe-box ""hi""))",
                  """#<box hi>""");

      Test_Value (VM, "(equal? (probe-box (list 1 2)) (probe-box (list 1 2)))",
                  "#t");
      Test_Value (VM, "(equal? (probe-box (list 1 2)) (probe-box (list 1 3)))",
                  "#f");
      Test_Value (VM, "(eq? (probe-box 1) (probe-box 1))", "#f");
      Test_Value
        (VM, "(equal? (list 0 (probe-box (vector 1 ""x"")))"
         & " (list 0 (probe-box (vector 1 ""x""))))",
         "#t");
      Test_Value
        (VM, "(equal? (list 0 (probe-box (vector 1 ""x"")))"
         & " (list 0 (probe-box (vector 1 ""y""))))",
         "#f");
   end Run_Tests;

   ----------
   -- Show --
   ----------

   overriding function Show
     (This        : Box;
      Show_Object : not null access function (X : Object) return String)
      return String
   is
   begin
      return "#<box " & Show_Object (This.Held) & ">";
   end Show;

   ----------------
   -- Test_Value --
   ----------------

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, Expected, VM.Show_Slot (1));
   end Test_Value;

end Raven.Tests.Foreign;
