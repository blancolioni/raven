package body Raven.Tests.Foreign is

   --  A box: a foreign value whose whole content is one object of the
   --  program's.  It is the smallest thing that cannot work unless
   --  the collector is told what a foreign value holds.

   type Box is new Foreign_Value_Instance with
      record
         Held : Object;
      end record;

   overriding function Show (This : Box) return String;

   --  How many boxes the collector has given back, which is how a
   --  test can see that letting go of a handle let go of what it
   --  named.  Nothing else can: an object that has been collected
   --  says nothing about it.

   Freed : Natural := 0;

   overriding procedure Free (This : in out Box);

   --  Equal is given no VM either, so a box cannot compare what it
   --  holds any more than it can print it.  Two boxes are the same
   --  box or they are not.

   overriding function Equal
     (This : Box;
      To   : Box)
      return Boolean
   is (This.Held = To.Held);

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
   end Run_Tests;

   ----------
   -- Show --
   ----------

   overriding function Show (This : Box) return String is
      pragma Unreferenced (This);
   begin
      --  Show is given no VM, so a box cannot say what it holds.
      --  Which is the same omission as the one this suite is about,
      --  in a place where getting it wrong is a poor answer rather
      --  than a corrupted heap.

      return "#box";
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
      Test (Expression, Expected, VM.Get_Slot (1));
   end Test_Value;

end Raven.Tests.Foreign;
