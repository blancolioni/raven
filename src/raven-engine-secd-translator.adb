with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Finalization;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Hash_Case_Insensitive;
with Ada.Text_IO;
with Raven.Instructions;
with Raven.Objects;
with Raven.Target;

package body Raven.Engine.SECD.Translator is

   use Raven.Instructions;
   use type Raven.Target.Library_Id;
   use type Raven.Target.Macro_Id;

   package Object_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Object);

   function Show_Code
     (Code : Object_Lists.List;
      Target : Raven.Target.Reference)
      return String;

   package Object_List_Vectors is
     new Ada.Containers.Vectors
       (Positive, Object_Lists.List, Object_Lists."=");

   package Root_Vectors is
     new Ada.Containers.Vectors (Positive, Object);

   type Root_Table is access all Root_Vectors.Vector;

   --  An object the translator has taken out of the form it is
   --  translating, and will use again after a call that can allocate,
   --  is held in a Root.  A collection can happen in the middle of a
   --  translation, because expanding a macro runs the machine: the
   --  collector keeps only what a container marks, and moves what it
   --  keeps without being able to reach into an Ada variable and
   --  correct it.  So the object lives in a table the translator marks,
   --  and Get reads the address it has now.  Roots belong to the scopes
   --  that declare them, and scopes nest, so the table is a stack: a
   --  Root gives back its slot, and every slot above it, when it goes.

   package Roots is

      type Root is new Ada.Finalization.Limited_Controlled with private;

      function Hold
        (Table : Root_Table;
         Value : Object)
         return Root;

      function Get (This : Root) return Object;

      procedure Set
        (This  : Root;
         Value : Object);

   private

      type Root is new Ada.Finalization.Limited_Controlled with
         record
            Table : Root_Table;
            Index : Positive := 1;
         end record;

      overriding procedure Finalize (This : in out Root);

      function Get (This : Root) return Object
      is (This.Table.all (This.Index));

   end Roots;

   use Roots;

   --  A name is bound either to a run time location, which LD and ST
   --  reach through a frame index and an offset, or to a macro, which
   --  the translator expands where it stands.  Both kinds share one
   --  chain, so that the innermost binding wins whichever it is.

   type Binding_Kind is (Variable_Binding, Macro_Binding);

   type Env_Entry (Kind : Binding_Kind := Variable_Binding) is
      record
         case Kind is
            when Variable_Binding =>
               Offset  : Natural;
               Is_List : Boolean;
            when Macro_Binding =>
               Macro   : Raven.Target.Real_Macro_Id;
         end case;
      end record;

   package Env_Maps is
     new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Env_Entry,
      Hash            => Ada.Strings.Hash_Case_Insensitive,
      Equivalent_Keys => Ada.Strings.Equal_Case_Insensitive);

   --  A run time frame is one the machine will build when it applies a
   --  closure, so it counts towards the frame index LD needs.  A scope
   --  frame exists only while a region is being translated, holding the
   --  macros defined in it, and does not.

   type Frame_Kind is (Run_Time_Frame, Scope_Frame);

   type Env_Frame is
      record
         Kind     : Frame_Kind;
         Bindings : Env_Maps.Map;
      end record;

   package Env_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Env_Frame);

   type Instance is new Raven.Translator.Abstraction with
      record
         Current : Positive := 1;
         Code    : Object_List_Vectors.Vector;
         Roots   : aliased Root_Vectors.Vector;
      end record;

   overriding procedure Translate
     (This    : in out Instance;
      Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id);

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

   procedure Append
     (This : in out Instance'Class;
      I    : Instruction);

   procedure Append
     (This : in out Instance'Class;
      C    : Object)
     with Pre => Objects.Is_Atom (C);

   ------------
   -- Append --
   ------------

   procedure Append
     (This : in out Instance'Class;
      I    : Instruction)
   is
   begin
      This.Code (This.Current).Append
        (Raven.Objects.To_Object (I));
   end Append;

   ------------
   -- Append --
   ------------

   procedure Append
     (This : in out Instance'Class;
      C    : Object)
   is
   begin
      This.Code (This.Current).Append (C);
   end Append;

   ------------
   -- Create --
   ------------

   function Create
     return Raven.Translator.Abstraction'Class
   is
   begin
      return Instance'(others => <>);
   end Create;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      --  The code lists hold the constants lifted out of the form,
      --  which nothing else names until Emit pushes them onto the
      --  machine's stack.

      for Level of This.Code loop
         for X of Level loop
            Process (X);
         end loop;
      end loop;

      for X of This.Roots loop
         Process (X);
      end loop;
   end Mark;

   -----------
   -- Roots --
   -----------

   package body Roots is

      --------------
      -- Finalize --
      --------------

      overriding procedure Finalize (This : in out Root) is
      begin
         if This.Table /= null
           and then This.Table.Last_Index >= This.Index
         then
            This.Table.Set_Length
              (Ada.Containers.Count_Type (This.Index - 1));
         end if;
         This.Table := null;
      end Finalize;

      ----------
      -- Hold --
      ----------

      function Hold
        (Table : Root_Table;
         Value : Object)
         return Root
      is
      begin
         Table.Append (Value);
         return This : Root do
            This.Table := Table;
            This.Index := Table.Last_Index;
         end return;
      end Hold;

      ---------
      -- Set --
      ---------

      procedure Set
        (This  : Root;
         Value : Object)
      is
      begin
         This.Table.all (This.Index) := Value;
      end Set;

   end Roots;

   ---------------
   -- Show_Code --
   ---------------

   function Show_Code
     (Code : Object_Lists.List;
      Target : Raven.Target.Reference)
      return String
   is
      use Object_Lists;
      function Show (Position : Cursor) return String
      is (if Has_Element (Position)
          then Target.Show (Element (Position))
          & " " & Show (Next (Position))
          else "");
   begin
      return Show (Code.First);
   end Show_Code;

   ---------------
   -- Translate --
   ---------------

   overriding procedure Translate
     (This    : in out Instance;
      Target  : Raven.Target.Reference;
      Library : Raven.Target.Real_Library_Id)
   is
      Env : Env_Lists.List;

      --  The library the code being read was written in.  It is
      --  Library until a macro is expanded, and the macro's own while
      --  its body is read, because that is where the body was
      --  written.  A translation that a macro expansion starts gets a
      --  Home of its own, so nesting looks after itself.
      --
      --  Expanding says which of the two is being read.  A macro's
      --  body is the macro's own code and nothing in it came from the
      --  caller, so it is read entirely in Home.  What the body
      --  produced is not: the caller's own forms are in it, and only
      --  a name the use site cannot account for is read in Home.

      Home      : Raven.Target.Real_Library_Id := Library;
      Expanding : Boolean := False;

      --  Which library a definition here belongs to, and so which one
      --  a macro defined here is named in.

      function Written_In return Raven.Target.Real_Library_Id
      is (if Expanding then Library else Home);

      --  Everything this translation is working with lives here, so
      --  that a collection provoked by a macro expansion neither takes
      --  it nor leaves the translator holding an address it has moved
      --  away from.

      Table : constant Root_Table := This.Roots'Unchecked_Access;

      procedure Append_Definition
        (Sym : Object);

      procedure Append_Reference
        (Sym : Object);

      procedure Bind_Macro
        (Name : String;
         Id   : Raven.Target.Real_Macro_Id);

      procedure Build_Env
        (Args : Object);

      procedure Close_Scope;

      procedure Compile_QQ
        (Template : Object;
         Level    : Positive);

      procedure Emit (Level : Positive);

      procedure Find_Binding
        (Name  : String;
         Found : out Boolean;
         Ent   : out Env_Entry);

      --  Tail says that the value of this form is the value of the
      --  body it stands in, so that a call here need save nothing.  It
      --  is false everywhere by default and true only where it is
      --  passed on: a body's last form, the branches of an if in tail
      --  position, the last form of a begin in tail position, and what
      --  a macro in tail position expanded to.  Never an argument, an
      --  operator, an if's condition, or a top level form, which has
      --  no body to return from.

      procedure Go
        (Form : Object;
         Tail : Boolean := False);

      function Head_Macro
        (F : Object)
         return Raven.Target.Macro_Id;

      procedure Locate (Sym : Object);

      procedure Nested
        (X    : Object;
         Last : Instruction;
         Tail : Boolean := False);

      procedure Nested_Sequence
        (X    : Object;
         Last : Instruction;
         Tail : Boolean := False);

      procedure Open_Scope;

      procedure Undefine_Macro
        (Sym : Object);

      S_Apply             : constant Object := Target.To_Symbol ("apply");
      S_Begin             : constant Object := Target.To_Symbol ("begin");
      S_Car               : constant Object := Target.To_Symbol ("car");
      S_Cdr               : constant Object := Target.To_Symbol ("cdr");
      S_Cons              : constant Object := Target.To_Symbol ("cons");
      S_Define            : constant Object := Target.To_Symbol ("define");
      S_Define_Macro      : constant Object :=
                              Target.To_Symbol ("define-macro");
      S_Eq                : constant Object := Target.To_Symbol ("raven-eq?");
      S_Pair              : constant Object := Target.To_Symbol ("pair?");
      S_Quasiquote        : constant Object := Target.To_Symbol ("quasiquote");
      S_Set               : constant Object := Target.To_Symbol ("set!");
      S_Unquote           : constant Object := Target.To_Symbol ("unquote");
      S_Unquote_Splicing  : constant Object :=
                              Target.To_Symbol ("unquote-splicing");
      Indent   : Natural := 0;

      -----------------------
      -- Append_Definition --
      -----------------------

      procedure Append_Definition
        (Sym : Object)
      is
         Name : constant String :=
                  Target.To_String (Objects.To_Symbol (Sym));
      begin
         --  A definition binds where it was written, whatever the name
         --  meant before: a library defines its own names and no one
         --  else's.

         Target.Define_Name (Written_In, Name);
         This.Append (Objects.To_Object (Integer (Written_In)));
         This.Append (Sym);
      end Append_Definition;

      ----------------------
      -- Append_Reference --
      ----------------------

      procedure Append_Reference
        (Sym : Object)
      is
         Name  : constant String :=
                   Target.To_String (Objects.To_Symbol (Sym));
         Found : Raven.Target.Real_Library_Id;
      begin
         --  Which library holds the name is settled here, so that the
         --  machine has nothing left to decide and a closure has
         --  nothing to carry.
         --
         --  In a macro's body, where every name was written by the
         --  macro, in the library the macro was written in.  That is
         --  what lets a library's macros reach what the library keeps
         --  to itself, and what stops a definition at the use site
         --  taking a name the macro meant.
         --
         --  In what the body produced, at the use site first, because
         --  the caller's own forms are in it and they mean what the
         --  caller wrote; then in the macro's library, for a name the
         --  use site cannot account for.
         --
         --  What that second rule cannot do is tell the two apart.
         --  Once a template has been instantiated the expansion is one
         --  form, and a name the caller passed in looks exactly like a
         --  name the template wrote.  So a caller's reference to a
         --  name it has not defined yet, which the macro's library
         --  defines, goes to that library instead, silently.  An
         --  identifier that carried where it was written would settle
         --  it; that is #24.

         if Home = Library then
            Found := Target.Resolve (Library, Name);
         elsif Expanding and then Target.Binds (Library, Name) then
            Found := Target.Resolve (Library, Name);
         else
            Found := Target.Resolve (Home, Name);
         end if;

         This.Append (Objects.To_Object (Integer (Found)));
         This.Append (Sym);
      end Append_Reference;

      ----------------
      -- Bind_Macro --
      ----------------

      procedure Bind_Macro
        (Name : String;
         Id   : Raven.Target.Real_Macro_Id)
      is
         Frame : constant Env_Lists.Reference_Type :=
                   Env.Reference (Env.Last);
         Position : constant Env_Maps.Cursor :=
                      Frame.Bindings.Find (Name);
      begin
         --  A second definition of the same name in the same region
         --  takes the name from the first, which nothing can name
         --  again, so the first is given back here.

         if Env_Maps.Has_Element (Position)
           and then Env_Maps.Element (Position).Kind = Macro_Binding
         then
            Target.Release_Macro (Env_Maps.Element (Position).Macro);
         end if;

         Frame.Bindings.Include (Name, Env_Entry'(Macro_Binding, Id));
      end Bind_Macro;

      ---------------
      -- Build_Env --
      ---------------

      procedure Build_Env
        (Args : Object)
      is
         use Raven.Objects;
         New_Env  : Env_Maps.Map;
         Offset   : Natural := 0;
         It       : Object  := Args;
      begin
         while Is_Pair (It) loop
            declare
               Arg : constant Object := Target.Car (It);
            begin
               if not Is_Symbol (Arg) then
                  raise Raven.Target.Translation_Error with
                    "arguments must be symbols; found "
                    & Target.Show (Arg);
               end if;
               New_Env.Insert
                 (Target.To_String (To_Symbol (Arg)),
                  Env_Entry'(Variable_Binding, Offset, False));
               It := Target.Cdr (It);
               Offset := Offset + 1;
            end;
         end loop;

         if It /= Raven.Objects.Nil then
            if not Is_Symbol (It) then
               raise Raven.Target.Translation_Error with
                 "arguments must be symbols; found "
                 & Target.Show (It);
            end if;
            New_Env.Insert
              (Target.To_String (To_Symbol (It)),
               Env_Entry'(Variable_Binding, Offset, True));
         end if;
         Env.Append (Env_Frame'(Run_Time_Frame, New_Env));
      end Build_Env;

      -----------------
      -- Close_Scope --
      -----------------

      procedure Close_Scope is
         Frame : constant Env_Frame := Env.Last_Element;
      begin
         --  The region is finished, so nothing can name a macro it
         --  defined any more, and the definition goes with it.  What
         --  the definition shares with the form being translated stays
         --  alive, because the form is a root of its own.

         for Ent of Frame.Bindings loop
            if Ent.Kind = Macro_Binding then
               Target.Release_Macro (Ent.Macro);
            end if;
         end loop;

         Env.Delete_Last;
      end Close_Scope;

      ----------------
      -- Compile_QQ --
      ----------------

      procedure Compile_QQ
        (Template : Object;
         Level    : Positive)
      is
         use Raven.Objects;
         T : constant Root := Hold (Table, Template);
      begin
         if Is_Atom (Get (T)) then
            This.Append (LDC);
            This.Append (Get (T));
         else
            declare
               Head : constant Root :=
                        Hold (Table, Target.Car (Get (T)));
               Tail : constant Root :=
                        Hold (Table, Target.Cdr (Get (T)));
            begin
               if Get (Head) = S_Unquote
                 or else Get (Head) = S_Unquote_Splicing
               then
                  --  An unquote belongs to the innermost quasiquote
                  --  around it.  At the level this one is building it
                  --  is evaluated; further in it is data like any
                  --  other, and what it holds is a template one level
                  --  out.

                  if Level > 1 then
                     Compile_QQ (Get (Tail), Level - 1);
                     Compile_QQ (Get (Head), Level - 1);
                     This.Append (CONS);
                  elsif Get (Head) = S_Unquote then
                     Go (Target.Car (Get (Tail)));
                  else
                     raise Raven.Target.Translation_Error with
                       "unquote-splicing: nothing to splice it into";
                  end if;
               elsif Get (Head) = S_Quasiquote then
                  --  A quasiquote inside a quasiquote is data, and
                  --  everything within it is one level further in.

                  Compile_QQ (Get (Tail), Level + 1);
                  Compile_QQ (Get (Head), Level + 1);
                  This.Append (CONS);
               elsif Level = 1
                 and then Is_Pair (Get (Head))
                 and then Target.Car (Get (Head)) = S_Unquote_Splicing
               then
                  --  The rest of the list first and the spliced value
                  --  on top, as the CONS below takes its head from the
                  --  top: what is on top goes in front.

                  Compile_QQ (Get (Tail), Level);
                  Go (Target.Cadr (Get (Head)));
                  This.Append (APPEND);
               else
                  Compile_QQ (Get (Tail), Level);
                  Compile_QQ (Get (Head), Level);
                  This.Append (CONS);
               end if;
            end;
         end if;
      end Compile_QQ;

      ----------
      -- Emit --
      ----------

      procedure Emit (Level : Positive) is
         use Object_Lists;
         Position : Cursor := This.Code (Level).First;
         Count    : Natural := 0;
      begin
         Indent := Indent + 2;
         while Has_Element (Position) loop
            declare
               X : constant Object := Element (Position);
            begin
               if X = Raven.Objects.Pending then
                  Next (Position);
                  Emit (Raven.Objects.To_Integer (Element (Position)));
               elsif X = Raven.Objects.To_Object (LD)
                 or else X = Raven.Objects.To_Object (ST)
                 or else X = Raven.Objects.To_Object (DFN)
               then
                  --  Two cells here, one object in the code the
                  --  machine runs: a frame and an offset for a name on
                  --  the stack, a library and a symbol for one a
                  --  library holds.

                  Target.Push (X);
                  Count := Count + 1;
                  Next (Position);
                  if not Has_Element (Position)
                    or else not Has_Element (Next (Position))
                  then
                     raise Constraint_Error with
                     "emit: missing operand: "
                       & Show_Code (This.Code (Level), Target);
                  end if;
                  Target.Push (Element (Position));
                  Next (Position);
                  Target.Push (Element (Position));
                  Target.Cons;
               else
                  Target.Push (X);
               end if;
               Count := Count + 1;
               Next (Position);
            end;
         end loop;
         Target.Push_Nil;
         for I in 1 .. Count loop
            Target.Cons;
         end loop;
         Indent := Indent - 2;
      end Emit;

      ------------------
      -- Find_Binding --
      ------------------

      procedure Find_Binding
        (Name  : String;
         Found : out Boolean;
         Ent   : out Env_Entry)
      is
      begin
         for Frame of reverse Env loop
            declare
               Position : constant Env_Maps.Cursor :=
                            Frame.Bindings.Find (Name);
            begin
               if Env_Maps.Has_Element (Position) then
                  Found := True;
                  Ent   := Env_Maps.Element (Position);
                  return;
               end if;
            end;
         end loop;
         Found := False;
         Ent   := Env_Entry'(Variable_Binding, 0, False);
      end Find_Binding;

      --------
      -- Go --
      --------

      procedure Go
        (Form  : Object;
         Tail  : Boolean := False)
      is
         X : constant Root := Hold (Table, Form);

         procedure Load_Constant (K : Object);

         procedure Load_Macro_Args (Args : Object);

         -------------------
         -- Load_Constant --
         -------------------

         procedure Load_Constant (K : Object) is
            use Raven.Objects;
         begin
            if Is_Atom (K) then
               This.Append (LDC);
               This.Append (K);
            elsif Is_Pair (K) then
               Load_Constant (Target.Cdr (K));
               Load_Constant (Target.Car (K));
               This.Append (CONS);
            else
               raise Constraint_Error with
                 "cannot load constant with: " & Target.Show (K);
            end if;
         end Load_Constant;

         ----------------------
         -- Load_Macro_Args  --
         ----------------------

         procedure Load_Macro_Args (Args : Object) is
         begin
            if Args = Objects.Nil then
               This.Append (LDC);
               This.Append (Objects.Nil);
            else
               Load_Macro_Args (Target.Cdr (Args));
               Load_Constant (Target.Car (Args));
               This.Append (CONS);
            end if;
         end Load_Macro_Args;

      begin
         if Raven.Objects.Is_Atom (Get (X)) then
            if Raven.Objects.Is_Symbol (Get (X)) then
               This.Append (LD);
               Locate (Get (X));
            else
               This.Append (LDC);
               This.Append (Get (X));
            end if;
         elsif Raven.Objects.Is_Pair (Get (X)) then
            declare
               F     : constant Root :=
                         Hold (Table, Target.Car (Get (X)));
               A     : constant Root :=
                         Hold (Table, Target.Cdr (Get (X)));
               Macro : constant Raven.Target.Macro_Id :=
                         Head_Macro (Get (F));

               --  What follows a special form has to be the shape the
               --  form is about to take apart, and every one of these
               --  used to find that out by taking it apart: (define)
               --  asked for the car of nil, which is a precondition
               --  on Raven.Pairs and so an assertion failure -- out
               --  of the machine and saying nothing about the form --
               --  rather than something a badly written program can
               --  be told.
               --
               --  Most is Natural'Last where a form takes as many as
               --  it is given.

               procedure Expect
                 (Least : Natural;
                  Most  : Natural;
                  Shape : String);

               ------------
               -- Expect --
               ------------

               procedure Expect
                 (Least : Natural;
                  Most  : Natural;
                  Shape : String)
               is
                  Count : Natural := 0;
                  It    : Object  := Get (A);
               begin
                  while Raven.Objects.Is_Pair (It) loop
                     Count := Count + 1;
                     It := Target.Cdr (It);
                  end loop;

                  if Count < Least or else Count > Most then
                     raise Raven.Target.Translation_Error with Shape;
                  end if;
               end Expect;

            begin
               if Get (F) = Raven.Objects.Quote then
                  Expect (1, 1, "quote takes one datum: (quote x)");
                  Load_Constant (Target.Cadr (Get (X)));
               elsif Get (F) = Raven.Objects.If_Obj then
                  Expect (2, 3,
                          "if takes a test, what to do, and what to do "
                          & "otherwise: (if test then else)");
                  declare
                     Args : constant Root := Hold (Table, Get (A));

                     --  Whichever branch is taken is what the if
                     --  answers with, so both are in tail position
                     --  exactly when the if is.  Then each branch
                     --  returns for itself and there is no rest of the
                     --  form to come back to, which is what lets TSEL
                     --  leave the dump alone.  The condition is never
                     --  in tail position: its value is tested here.

                     Ends : constant Instruction :=
                              (if Tail then RTN else JOIN);
                  begin
                     Go (Target.Car (Get (Args)));
                     This.Append (if Tail then TSEL else SEL);
                     Set (Args, Target.Cdr (Get (Args)));
                     Nested (Target.Car (Get (Args)), Ends, Tail);
                     --  Whether there is an else, which is whether
                     --  anything follows the then -- not whether the
                     --  then is there, which it is by now.  Asking
                     --  the wrong one of those made (if #t 1) ask
                     --  for the cadr of a list of one.

                     if Objects.Is_Pair (Target.Cdr (Get (Args))) then
                        Nested (Target.Cadr (Get (Args)), Ends, Tail);
                     else
                        Nested (Objects.Nil, Ends, Tail);
                     end if;
                  end;
               elsif Get (F) = S_Begin then
                  declare
                     use Raven.Objects;
                     Arg : constant Root := Hold (Table, Get (A));
                  begin
                     while Is_Pair (Get (Arg)) loop

                        --  Only the last form answers for the begin,
                        --  so only the last can be in tail position.
                        --  The ones before it are dropped, which is
                        --  also what leaves the stack empty for a call
                        --  in the last one to be a tail call at all.

                        Go (Target.Car (Get (Arg)),
                            Tail and then not Is_Pair
                              (Target.Cdr (Get (Arg))));
                        Set (Arg, Target.Cdr (Get (Arg)));
                        if Is_Pair (Get (Arg)) then
                           This.Append (DROP);
                        end if;
                     end loop;
                  end;
               elsif Get (F) = Raven.Objects.Lambda then
                  Expect (2, Natural'Last,
                          "lambda takes a parameter list and a body: "
                          & "(lambda (x ...) body ...)");
                  Build_Env (Target.Car (Get (A)));
                  This.Append (LDF);
                  Nested_Sequence (Target.Cdr (Get (A)), RTN, Tail => True);
                  Close_Scope;
               elsif Get (F) = S_Set then
                  Expect (2, 2,
                          "set! takes a name and a value: (set! x v)");
                  if not Raven.Objects.Is_Symbol (Target.Car (Get (A)))
                  then
                     raise Raven.Target.Translation_Error with
                       "set! requires a symbol as its first argument";
                  end if;
                  Go (Target.Cadr (Get (A)));
                  This.Append (ST);
                  Locate (Target.Car (Get (A)));
               elsif Get (F) = S_Eq then
                  Expect (2, 2,
                          "raven-eq? takes two forms: (raven-eq? a b)");
                  Go (Target.Car (Get (A)));
                  Go (Target.Cadr (Get (A)));
                  This.Append (EQ);
               elsif Get (F) = S_Car then
                  Expect (1, 1, "car takes one form: (car x)");
                  Go (Target.Car (Get (A)));
                  This.Append (CAR);
               elsif Get (F) = S_Cdr then
                  Expect (1, 1, "cdr takes one form: (cdr x)");
                  Go (Target.Car (Get (A)));
                  This.Append (CDR);
               elsif Get (F) = S_Cons then
                  Expect (2, 2, "cons takes two forms: (cons a b)");
                  Go (Target.Cadr (Get (A)));
                  Go (Target.Car (Get (A)));
                  This.Append (CONS);
               elsif Get (F) = S_Apply then

                  --  apply needs nothing of the machine that a call
                  --  does not already need.  A call builds a list of
                  --  its arguments, pushes what it is calling on top
                  --  of it and says AP, and AP takes the list off the
                  --  stack; so a call whose argument list is already
                  --  built is that same sequence with the building
                  --  left out.
                  --
                  --  (apply f xs) is therefore xs pushed, then f on
                  --  top of it, then AP.  R7RS lets arguments be written in
                  --  front of the list, and those are consed onto it
                  --  here, innermost first, which is the order
                  --  Compile_Args uses for an ordinary call.

                  declare
                     procedure Compile_Spread (Args : Object);

                     --------------------
                     -- Compile_Spread --
                     --------------------

                     procedure Compile_Spread (Args : Object) is
                        Arg : constant Root := Hold (Table, Args);
                     begin
                        if Target.Cdr (Get (Arg)) = Objects.Nil then
                           Go (Target.Car (Get (Arg)));
                        else
                           Compile_Spread (Target.Cdr (Get (Arg)));
                           Go (Target.Car (Get (Arg)));
                           This.Append (CONS);
                        end if;
                     end Compile_Spread;

                  begin
                     Expect (2, Natural'Last,
                             "apply takes a procedure and a list of "
                             & "arguments: (apply f xs)");

                     Compile_Spread (Target.Cdr (Get (A)));
                     Go (Target.Car (Get (A)));
                     This.Append (if Tail then TAP else AP);
                  end;
               elsif Get (F) = S_Pair then
                  Expect (1, 1, "pair? takes one form: (pair? x)");
                  Go (Target.Car (Get (A)));
                  This.Append (PAIR);
               elsif Get (F) = S_Quasiquote then
                  Expect (1, 1, "quasiquote takes one datum: (quasiquote x)");
                  Compile_QQ (Target.Car (Get (A)), 1);
               elsif Get (F) = S_Define then
                  Expect (2, Natural'Last,
                          "define takes a name and a value, or a header "
                          & "and a body: (define x v), (define (f x) body)");
                  if Raven.Objects.Is_Symbol (Target.Car (Get (A))) then
                     Expect (2, 2,
                             "define of a name takes one value: "
                             & "(define x v)");
                     Undefine_Macro (Target.Car (Get (A)));
                     Go (Target.Cadr (Get (A)));
                     This.Append (DFN);
                     Append_Definition (Target.Car (Get (A)));
                  elsif Raven.Objects.Is_Pair (Target.Car (Get (A))) then
                     Undefine_Macro (Target.Caar (Get (A)));
                     Build_Env (Target.Cdar (Get (A)));
                     This.Append (LDF);
                     Nested_Sequence (Target.Cdr (Get (A)), RTN, Tail => True);
                     Close_Scope;
                     This.Append (DFN);
                     Append_Definition (Target.Caar (Get (A)));
                  else
                     raise Raven.Target.Translation_Error with
                       "define takes a name or a header, not "
                       & Target.Show (Target.Car (Get (A)));
                  end if;
               elsif Get (F) = S_Define_Macro then
                  Expect (2, Natural'Last,
                          "define-macro takes a header and a body: "
                          & "(define-macro (name params ...) body ...)");
                  if not Raven.Objects.Is_Pair (Target.Car (Get (A)))
                    or else not Raven.Objects.Is_Symbol
                                  (Target.Caar (Get (A)))
                  then
                     raise Raven.Target.Translation_Error with
                       "define-macro: first argument must be "
                       & "(name params ...)";
                  end if;
                  declare
                     Name_Sym   : constant Object := Target.Caar (Get (A));
                     Name       : constant String :=
                                    Target.To_String
                                      (Raven.Objects.To_Symbol (Name_Sym));
                     Params     : constant Object := Target.Cdar (Get (A));
                     Macro_Body : constant Object := Target.Cdr (Get (A));
                     Id         : constant Raven.Target.Real_Macro_Id :=
                                    Target.Store_Macro
                                      (Params, Macro_Body,
                                       Home, Written_In);
                  begin
                     --  The definition belongs to the region being
                     --  translated.  Only a form at top level, where
                     --  there is no enclosing region, defines in the
                     --  library.
                     --
                     --  Where the name goes and where the macro was
                     --  written are two things.  define-syntax expands
                     --  to a define-macro, so a macro written this way
                     --  in one library is named in the library that
                     --  used define-syntax, and written in the library
                     --  define-syntax came from -- which is the only
                     --  place the names in its body mean anything.

                     if Env.Is_Empty then
                        Undefine_Macro (Name_Sym);
                        Target.Define_Macro (Written_In, Name, Id);
                     else
                        Bind_Macro (Name, Id);
                     end if;
                     This.Append (LDC);
                     This.Append (Name_Sym);
                  end;
               else
                  if Macro /= Raven.Target.No_Macro then
                     declare
                        Params_Obj      : Object;
                        Body_Obj        : Object;
                        Macro_Home      : Raven.Target.Real_Library_Id;
                        Macro_Expansion : Raven.Target.Real_Library_Id;
                        Old_Home        : constant
                          Raven.Target.Real_Library_Id := Home;
                        Old_Expanding   : constant Boolean := Expanding;
                        Old_Current     : constant Positive := This.Current;
                        Expansion_Level : Positive;
                     begin
                        Target.Get_Macro
                          (Macro, Params_Obj, Body_Obj,
                           Macro_Home, Macro_Expansion);

                        --  The body is the text whoever wrote the
                        --  macro wrote, read in their library.

                        Home      := Macro_Home;
                        Expanding := False;

                        declare
                           Params     : constant Root :=
                                          Hold (Table, Params_Obj);
                           Macro_Body : constant Root :=
                                          Hold (Table, Body_Obj);
                        begin
                           This.Code.Append (Object_Lists.Empty_List);
                           Expansion_Level := This.Code.Last_Index;
                           This.Current    := Expansion_Level;
                           Load_Macro_Args (Get (A));
                           Build_Env (Get (Params));
                           This.Append (LDF);
                           Nested_Sequence (Get (Macro_Body), RTN);
                           Close_Scope;
                           This.Append (AP);
                           This.Append (STOP);
                           This.Current := Old_Current;
                           Emit (Expansion_Level);
                           Target.Execute;
                        end;

                        --  What the body produced has the caller's
                        --  forms in it, so it is read here first, and
                        --  in the library the macro was defined in for
                        --  a name here cannot account for.

                        Home      := Macro_Expansion;
                        Expanding := True;
                        Go (Target.Pop, Tail);

                        Home      := Old_Home;
                        Expanding := Old_Expanding;
                     end;
                  else
                     declare
                        procedure Compile_Args (Args : Object);

                        ------------------
                        -- Compile_Args --
                        ------------------

                        procedure Compile_Args (Args : Object) is
                           Arg : constant Root := Hold (Table, Args);
                        begin
                           if Get (Arg) = Objects.Nil then
                              This.Append (LDC);
                              This.Append (Objects.Nil);
                           else
                              Compile_Args (Target.Cdr (Get (Arg)));
                              Go (Target.Car (Get (Arg)));
                              This.Append (CONS);
                           end if;
                        end Compile_Args;

                     begin
                        Compile_Args (Get (A));
                        Go (Get (F));
                        This.Append (if Tail then TAP else AP);
                     end;
                  end if;
               end if;
            end;
         end if;

      end Go;

      ----------------
      -- Head_Macro --
      ----------------

      function Head_Macro
        (F : Object)
         return Raven.Target.Macro_Id
      is
      begin
         if not Raven.Objects.Is_Symbol (F) then
            return Raven.Target.No_Macro;
         end if;

         declare
            Name  : constant String :=
                      Target.To_String (Raven.Objects.To_Symbol (F));
            Found : Boolean;
            Ent   : Env_Entry;
         begin
            Find_Binding (Name, Found, Ent);

            --  The innermost binding wins.  A lexical variable of this
            --  name is a procedure to call, and hides a macro of the
            --  same name bound further out.

            if not Found then
               --  As a name that is not a macro is resolved: a
               --  macro's body means the macros of the library it was
               --  written in, and what the body produced means the
               --  use site's first.

               if Home = Library then
                  return Target.Macro (Library, Name);
               elsif not Expanding then
                  return Target.Macro (Home, Name);
               else
                  declare
                     Id : constant Raven.Target.Macro_Id :=
                            Target.Macro (Library, Name);
                  begin
                     if Id = Raven.Target.No_Macro then
                        return Target.Macro (Home, Name);
                     end if;
                     return Id;
                  end;
               end if;
            elsif Ent.Kind = Macro_Binding then
               return Ent.Macro;
            else
               return Raven.Target.No_Macro;
            end if;
         end;
      end Head_Macro;

      ------------
      -- Locate --
      ------------

      procedure Locate (Sym : Object) is
         Name : constant String :=
                  Target.To_String (Objects.To_Symbol (Sym));
         I : Natural := 0;
      begin
         for Frame of reverse Env loop
            declare
               Position : constant Env_Maps.Cursor :=
                            Frame.Bindings.Find (Name);
            begin
               if Env_Maps.Has_Element (Position) then
                  declare
                     Ent : constant Env_Entry := Env_Maps.Element (Position);
                  begin
                     if Ent.Kind = Macro_Binding then
                        raise Raven.Target.Translation_Error with
                          "macro used as a variable: " & Name;
                     end if;
                     This.Append (Objects.To_Object (I));
                     if Ent.Is_List then
                        This.Append (Objects.To_Object (-Ent.Offset - 1));
                     else
                        This.Append (Objects.To_Object (Ent.Offset));
                     end if;
                  end;
                  return;
               end if;
            end;
            if Frame.Kind = Run_Time_Frame then
               I := @ + 1;
            end if;
         end loop;

         --  Nothing lexical holds the name, so a library does.

         Append_Reference (Sym);
      end Locate;

      ------------
      -- Nested --
      ------------

      procedure Nested
        (X    : Object;
         Last : Instruction;
         Tail : Boolean := False)
      is
         Old_Level : constant Natural := This.Current;
         New_Level : Natural;
      begin
         This.Code.Append (Object_Lists.Empty_List);
         This.Current := This.Code.Last_Index;
         New_Level := This.Current;
         Open_Scope;
         Go (X, Tail);
         Close_Scope;
         if Last /= NOP then
            This.Append (Last);
         end if;
         This.Current := Old_Level;
         This.Append (Objects.Pending);
         This.Append (Objects.To_Object (New_Level));
      end Nested;

      ---------------------
      -- Nested_Sequence --
      ---------------------

      procedure Nested_Sequence
        (X    : Object;
         Last : Instruction;
         Tail : Boolean := False)
      is
         use Raven.Objects;
         Old_Level : constant Natural := This.Current;
         New_Level : Natural;
         It        : constant Root := Hold (Table, X);
      begin
         This.Code.Append (Object_Lists.Empty_List);
         This.Current := This.Code.Last_Index;
         New_Level := This.Current;
         Open_Scope;
         while Is_Pair (Get (It)) loop

            --  A body answers with its last form and drops the rest,
            --  so the last form is the one in tail position.

            Go (Target.Car (Get (It)),
                Tail and then not Is_Pair (Target.Cdr (Get (It))));
            Set (It, Target.Cdr (Get (It)));
            if Is_Pair (Get (It)) then
               This.Append (DROP);
            end if;
         end loop;
         Close_Scope;

         if Last /= NOP then
            This.Append (Last);
         end if;
         This.Current := Old_Level;
         This.Append (Objects.Pending);
         This.Append (Objects.To_Object (New_Level));
      end Nested_Sequence;

      ----------------
      -- Open_Scope --
      ----------------

      procedure Open_Scope is
      begin
         Env.Append (Env_Frame'(Scope_Frame, Env_Maps.Empty_Map));
      end Open_Scope;

      --------------------
      -- Undefine_Macro --
      --------------------

      procedure Undefine_Macro (Sym : Object) is
      begin
         --  Defining a name takes it back from any macro that held it,
         --  which is the only way to undefine one.  The definition it
         --  displaces belongs to an earlier translation, and this one
         --  roots whatever it took from it, so it goes now.
         --
         --  Only what this library itself has: a macro it imported is
         --  another library's, and giving that back would hand its id
         --  to the next macro stored, leaving everyone who named it
         --  naming something else.  A definition here shadows it
         --  without taking it.

         if Env.Is_Empty
           and then Raven.Objects.Is_Symbol (Sym)
         then
            declare
               Name : constant String :=
                        Target.To_String (Raven.Objects.To_Symbol (Sym));
               Old  : constant Raven.Target.Macro_Id :=
                        Target.Own_Macro (Written_In, Name);
            begin
               if Old /= Raven.Target.No_Macro then
                  Target.Undefine_Macro (Written_In, Name);
                  Target.Release_Macro (Old);
               end if;
            end;
         end if;
      end Undefine_Macro;

   begin
      This.Code.Append (Object_Lists.Empty_List);
      Go (Target.Pop);
      This.Append (STOP);
      Emit (1);
   exception
      when E : others =>

         --  This used to report and return, so a form the translator
         --  refused looked to its caller exactly like one it had
         --  read.  Evaluate translated and then executed whatever had
         --  been emitted before the refusal, which for a form refused
         --  early is nothing at all, and the machine read an
         --  instruction off an empty code list and failed a
         --  precondition -- out of the machine, taking the host with
         --  it.  Nobody could catch a syntax error, because none ever
         --  reached them.
         --
         --  So it says what happened and raises, and the message goes
         --  where an error goes.  Read_Forms takes it from here for a
         --  form in a file, the way it already takes an undefined
         --  name: the file carries on at the form after it.

         Target.Report_Error (Ada.Exceptions.Exception_Message (E));

         --  And the code listing is for whoever is working on the
         --  translator, so it waits to be asked for.

         if Target.Tracing then
            for I in 1 .. This.Code.Last_Index loop
               Ada.Text_IO.Put (I'Image);
               Ada.Text_IO.Set_Col (5);
               Ada.Text_IO.Put_Line (Show_Code (This.Code (I), Target));
            end loop;
         end if;

         raise;
   end Translate;

end Raven.Engine.SECD.Translator;
