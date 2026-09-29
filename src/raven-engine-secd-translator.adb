with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Finalization;
with Ada.Strings.Hash;
with Ada.Text_IO;
with Raven.Instructions;
with Raven.Objects;
with Raven.Target;

package body Raven.Engine.SECD.Translator is

   use Raven.Instructions;

   package Object_Sets is new Ada.Containers.Ordered_Sets (Object);
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

   --  Names are compared as they are written, as symbols are (#160):
   --  this still folded case, so Foo and foo were one name here.

   package Env_Maps is
     new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Env_Entry,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

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

   --  A datum loaded whole, pairs and all (#167), which only LDC takes:
   --  the code lists are marked, so the collector moves it with them,
   --  and Emit pushes it as it is.

   procedure Append_Datum
     (This : in out Instance'Class;
      C    : Object);

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

   ------------------
   -- Append_Datum --
   ------------------

   procedure Append_Datum
     (This : in out Instance'Class;
      C    : Object)
   is
   begin
      This.Code (This.Current).Append (C);
   end Append_Datum;

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

      --  Whether what is being read came from syntax-rules (#178).  Every
      --  name such a template wrote is an alias, so a plain name in its
      --  expansion is the caller's, and means what it means at the use
      --  site and nowhere else.  What a define-macro wrote may be its
      --  own, and is looked for in its library after the use site.

      Hygienic  : Boolean := False;

      --  Where the macro whose expansion is being read was used, which is
      --  where a name the caller passed in means something.  That was
      --  taken to be Library, the library being translated, which it is
      --  for a macro used in what the library wrote; but a macro used in
      --  another macro's body was used where that body was written, and
      --  one used in another macro's expansion where that one was used.

      Use_Site  : Raven.Target.Real_Library_Id := Library;

      --  Which library a definition here belongs to, and so which one
      --  a macro defined here is named in.

      function Written_In return Raven.Target.Real_Library_Id
      is (if Expanding then Use_Site else Home);

      --  Everything this translation is working with lives here, so
      --  that a collection provoked by a macro expansion neither takes
      --  it nor leaves the translator holding an address it has moved
      --  away from.

      Table : constant Root_Table := This.Roots'Unchecked_Access;

      procedure Append_Definition
        (Sym : Object);

      procedure Append_Reference
        (Sym : Object);

      --  The library a name is held in and the name it is held under,
      --  appended, for a name to be read in Where.

      procedure Append_Reference_In
        (Where : Raven.Target.Real_Library_Id;
         Sym   : Object);

      --  Aliases (#24).  An alias is the symbol syntax-rules writes for
      --  a name its template wrote and did not bind: generated, so that
      --  nothing the caller writes is it, and knowing the name it
      --  stands for and the library the macro was written in.  Plain is
      --  that name, however many aliases deep, and anything that is not
      --  an alias as it is; Alias_Home is the library of the innermost.

      function Is_Alias (Sym : Object) return Boolean;

      function Plain (Sym : Object) return Object;

      function Alias_Home
        (Sym : Object)
         return Raven.Target.Real_Library_Id
        with Pre => Is_Alias (Sym);

      --  Whether a lexical binding holds Name, and its address appended
      --  when one does.

      function Try_Lexical (Name : String) return Boolean;

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

      function Head_Name (F : Object) return Object;

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
      S_Syntax_Quote      : constant Object :=
                              Target.To_Symbol ("raven-syntax-quote");
      S_Set               : constant Object := Target.To_Symbol ("set!");
      S_Unquote           : constant Object := Target.To_Symbol ("unquote");
      S_Unquote_Splicing  : constant Object :=
                              Target.To_Symbol ("unquote-splicing");
      Indent   : Natural := 0;

      ----------------
      -- Alias_Home --
      ----------------

      function Alias_Home
        (Sym : Object)
         return Raven.Target.Real_Library_Id
      is
         Id   : Objects.Symbol_Id := Objects.To_Symbol (Sym);
         Home : Natural := Target.Alias_Library (Id);
      begin
         loop
            Id := Target.Alias_Original (Id);
            exit when Target.Alias_Library (Id) = 0;
            Home := Target.Alias_Library (Id);
         end loop;
         return Raven.Target.Real_Library_Id (Home);
      end Alias_Home;

      -----------------------
      -- Append_Definition --
      -----------------------

      procedure Append_Definition
        (Sym : Object)
      is
         --  A name a template defines at top level is defined as the
         --  name it wrote (#24), which is what it was before aliases,
         --  and what a macro that defines a name of its own expects.

         Defined : constant Object := Plain (Sym);
         Name    : constant String :=
                     Target.To_String (Objects.To_Symbol (Defined));
      begin
         --  A definition binds where it was written, whatever the name
         --  meant before: a library defines its own names and no one
         --  else's.

         Target.Define_Name (Written_In, Name);
         This.Append (Objects.To_Object (Integer (Written_In)));
         This.Append (Defined);
      end Append_Definition;

      ----------------------
      -- Append_Reference --
      ----------------------

      procedure Append_Reference
        (Sym : Object)
      is
         Name  : constant String :=
                   Target.To_String (Objects.To_Symbol (Sym));
         Where : Raven.Target.Real_Library_Id;
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
         --  A name a syntax-rules template wrote is not one of these:
         --  it is an alias (#24), which Locate reads where the template
         --  was written.  So a plain name in what syntax-rules made is
         --  one the caller passed in, and is the use site's (#178), even
         --  where the use site has not defined it yet and the macro's
         --  library has.  What a define-macro made may hold names of its
         --  own, which is what the rule above is still for.
         --
         --  A name neither library accounts for is the use site's
         --  (#168).  It went to the macro's library, where nothing
         --  would ever define it, so a caller's forward or recursive
         --  reference through a macro -- (define (ints n) (delay (cons
         --  n (ints (+ n 1))))) -- was undefined for good.  At the use
         --  site it means whatever the caller goes on to define.

         if not Expanding then
            Where := Home;
         elsif Hygienic then
            Where := Use_Site;
         elsif Target.Binds (Use_Site, Name)
           or else not Target.Binds (Home, Name)
         then
            Where := Use_Site;
         else
            Where := Home;
         end if;

         Append_Reference_In (Where, Sym);
      end Append_Reference;

      -------------------------
      -- Append_Reference_In --
      -------------------------

      procedure Append_Reference_In
        (Where : Raven.Target.Real_Library_Id;
         Sym   : Object)
      is
         Name  : constant String :=
                   Target.To_String (Objects.To_Symbol (Sym));
         Found : constant Raven.Target.Real_Library_Id :=
                   Target.Resolve (Where, Name);

         --  And by the name that library holds it under, which is not
         --  the name written when it was imported through a rename.

         Held  : constant String := Target.Resolved_Name (Where, Name);
      begin
         This.Append (Objects.To_Object (Integer (Found)));
         This.Append
           (if Held = Name then Sym else Target.To_Symbol (Held));
      end Append_Reference_In;

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

            --  Data, so a name a template wrote is the name it wrote
            --  (#24), as in a quote.

            This.Append (LDC);
            This.Append (Plain (Get (T)));
         else
            declare
               Head : constant Root :=
                        Hold (Table, Target.Car (Get (T)));
               Tail : constant Root :=
                        Hold (Table, Target.Cdr (Get (T)));
            begin
               if Plain (Get (Head)) = S_Unquote
                 or else Plain (Get (Head)) = S_Unquote_Splicing
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
                  elsif Plain (Get (Head)) = S_Unquote then
                     Go (Target.Car (Get (Tail)));
                  else
                     raise Raven.Target.Translation_Error with
                       "unquote-splicing: nothing to splice it into";
                  end if;
               elsif Plain (Get (Head)) = S_Quasiquote then
                  --  A quasiquote inside a quasiquote is data, and
                  --  everything within it is one level further in.

                  Compile_QQ (Get (Tail), Level + 1);
                  Compile_QQ (Get (Head), Level + 1);
                  This.Append (CONS);
               elsif Level = 1
                 and then Is_Pair (Get (Head))
                 and then Plain (Target.Car (Get (Head))) = S_Unquote_Splicing
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

         --  Strip is whether a name a template wrote is loaded as the
         --  name it wrote (#24).  A quote's datum is; what a macro is
         --  handed is not, because the macro's own expansion is code in
         --  which each alias still has to mean what it meant.

         procedure Load_Constant
           (K     : Object;
            Strip : Boolean := True);

         procedure Load_Macro_Args (Args : Object);

         --  A quote's datum.  One that reaches a pair more than once --
         --  shared, or running back into itself, which datum labels
         --  make (#167) -- is loaded as the one object it is: building
         --  it again pair by pair would make two of what was one, and
         --  would never finish one that runs round.

         procedure Load_Quoted (K : Object);

         --  raven-syntax-quote's datum (#180): a quote that leaves an
         --  alias in it an alias, which is how define-syntax hands its
         --  rules to the expander.  Rules a template wrote are full of
         --  aliases, each meaning what it meant where that template was
         --  written, and a quote read them as the names they stood for.

         procedure Load_Syntax (K : Object);

         function Reaches_Twice (K : Object) return Boolean;

         -------------------
         -- Load_Constant --
         -------------------

         procedure Load_Constant
           (K     : Object;
            Strip : Boolean := True)
         is
            use Raven.Objects;
         begin
            if Is_Atom (K) then
               This.Append (LDC);
               This.Append (if Strip then Plain (K) else K);
            elsif Is_Pair (K) then
               Load_Constant (Target.Cdr (K), Strip);
               Load_Constant (Target.Car (K), Strip);
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

               --  An argument that shares structure, or runs back into
               --  itself, goes to the macro as the one object it is.

               if Raven.Objects.Is_Pair (Target.Car (Args))
                 and then Reaches_Twice (Target.Car (Args))
               then
                  This.Append (LDC);
                  This.Append_Datum (Target.Car (Args));
               else
                  Load_Constant (Target.Car (Args), Strip => False);
               end if;
               This.Append (CONS);
            end if;
         end Load_Macro_Args;

         -----------------
         -- Load_Quoted --
         -----------------

         procedure Load_Quoted (K : Object) is
         begin
            if Raven.Objects.Is_Pair (K) and then Reaches_Twice (K) then
               This.Append (LDC);
               This.Append_Datum (K);
            else
               Load_Constant (K);
            end if;
         end Load_Quoted;

         -----------------
         -- Load_Syntax --
         -----------------

         procedure Load_Syntax (K : Object) is
         begin
            if Raven.Objects.Is_Pair (K) and then Reaches_Twice (K) then
               This.Append (LDC);
               This.Append_Datum (K);
            else
               Load_Constant (K, Strip => False);
            end if;
         end Load_Syntax;

         -------------------
         -- Reaches_Twice --
         -------------------

         function Reaches_Twice (K : Object) return Boolean is
            Seen : Object_Sets.Set;

            function Walk (Item : Object) return Boolean;

            ----------
            -- Walk --
            ----------

            function Walk (Item : Object) return Boolean is
               It : Object := Item;
            begin
               while Raven.Objects.Is_Pair (It) loop
                  if Seen.Contains (It) then
                     return True;
                  end if;
                  Seen.Insert (It);

                  if Walk (Target.Car (It)) then
                     return True;
                  end if;

                  It := Target.Cdr (It);
               end loop;
               return False;
            end Walk;

         begin
            return Walk (K);
         end Reaches_Twice;

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

               --  What the head is as a special form.  A template's
               --  begin or define is an alias (#24), and is still begin
               --  or define unless something here binds the alias.

               H     : constant Object := Head_Name (Get (F));

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
               if H = Raven.Objects.Quote then
                  Expect (1, 1, "quote takes one datum: (quote x)");
                  Load_Quoted (Target.Cadr (Get (X)));
               elsif H = S_Syntax_Quote then
                  Expect (1, 1,
                          "raven-syntax-quote takes one datum: "
                          & "(raven-syntax-quote x)");
                  Load_Syntax (Target.Cadr (Get (X)));
               elsif H = Raven.Objects.If_Obj then
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
               elsif H = S_Begin then
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
               elsif H = Raven.Objects.Lambda then
                  Expect (2, Natural'Last,
                          "lambda takes a parameter list and a body: "
                          & "(lambda (x ...) body ...)");
                  Build_Env (Target.Car (Get (A)));
                  This.Append (LDF);
                  Nested_Sequence (Target.Cdr (Get (A)), RTN, Tail => True);
                  Close_Scope;
               elsif H = S_Set then
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
               elsif H = S_Eq then
                  Expect (2, 2,
                          "raven-eq? takes two forms: (raven-eq? a b)");
                  Go (Target.Car (Get (A)));
                  Go (Target.Cadr (Get (A)));
                  This.Append (EQ);
               elsif H = S_Car then
                  Expect (1, 1, "car takes one form: (car x)");
                  Go (Target.Car (Get (A)));
                  This.Append (CAR);
               elsif H = S_Cdr then
                  Expect (1, 1, "cdr takes one form: (cdr x)");
                  Go (Target.Car (Get (A)));
                  This.Append (CDR);
               elsif H = S_Cons then
                  Expect (2, 2, "cons takes two forms: (cons a b)");
                  Go (Target.Cadr (Get (A)));
                  Go (Target.Car (Get (A)));
                  This.Append (CONS);
               elsif H = S_Apply then

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
               elsif H = S_Pair then
                  Expect (1, 1, "pair? takes one form: (pair? x)");
                  Go (Target.Car (Get (A)));
                  This.Append (PAIR);
               elsif H = S_Quasiquote then
                  Expect (1, 1, "quasiquote takes one datum: (quasiquote x)");
                  Compile_QQ (Target.Car (Get (A)), 1);
               elsif H = S_Define then
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
               elsif H = S_Define_Macro then
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

                     --  At top level a macro a template names is named as
                     --  the template wrote it, as a definition is (#24).

                     Global     : constant String :=
                                    Target.To_String
                                      (Raven.Objects.To_Symbol
                                         (Plain (Name_Sym)));
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
                        Target.Define_Macro (Written_In, Global, Id);
                     else
                        Bind_Macro (Name, Id);
                     end if;
                     This.Append (LDC);
                     This.Append (Plain (Name_Sym));
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
                        Old_Hygienic    : constant Boolean := Hygienic;
                        Old_Use_Site    : constant
                          Raven.Target.Real_Library_Id := Use_Site;
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
                        Hygienic  := False;

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

                           --  What the body makes aliases for stands in
                           --  the library the macro was written in.

                           declare
                              Old_Expansion : constant
                                Raven.Target.Library_Id :=
                                  Target.Expansion_Library;
                           begin
                              Target.Set_Expansion_Library
                                (Macro_Expansion);
                              Target.Set_Hygienic (False);

                              --  And where it is used, for syntax-rules
                              --  to match its literals by (#179): where
                              --  a name the caller passed in means what
                              --  it means, which is what Use_Site will be
                              --  while the expansion is read.

                              Target.Clear_Use_Site;
                              Target.Set_Use_Site
                                (if Old_Expanding then Old_Use_Site
                                 else Old_Home);
                              for Frame of Env loop
                                 for Position in Frame.Bindings.Iterate loop
                                    Target.Add_Bound_Name
                                      (Env_Maps.Key (Position));
                                 end loop;
                              end loop;

                              Target.Execute;
                              Hygienic := Target.Hygienic;
                              Target.Clear_Use_Site;
                              Target.Set_Expansion_Library (Old_Expansion);
                           exception
                              when others =>
                                 Target.Clear_Use_Site;
                                 Target.Set_Expansion_Library
                                   (Old_Expansion);
                                 raise;
                           end;
                        end;

                        --  What the body produced has the caller's
                        --  forms in it, so it is read here first, and
                        --  in the library the macro was defined in for
                        --  a name here cannot account for.

                        Home      := Macro_Expansion;
                        Expanding := True;
                        Use_Site  :=
                          (if Old_Expanding then Old_Use_Site else Old_Home);
                        Go (Target.Pop, Tail);

                        Home      := Old_Home;
                        Expanding := Old_Expanding;
                        Hygienic  := Old_Hygienic;
                        Use_Site  := Old_Use_Site;
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
            --
            --  A template's name for a macro (#24) is that macro where
            --  the template was written; then, as a name is, one bound
            --  here, which is where a macro a body defined is; then the
            --  use site's.

            if not Found and then Is_Alias (F) then
               declare
                  Written  : constant String :=
                               Target.To_String
                                 (Raven.Objects.To_Symbol (Plain (F)));
                  Id       : constant Raven.Target.Macro_Id :=
                               Target.Macro (Alias_Home (F), Written);
                  Found_It : Boolean;
                  Local    : Env_Entry;
               begin
                  if Id /= Raven.Target.No_Macro then
                     return Id;
                  end if;

                  Find_Binding (Written, Found_It, Local);

                  if Found_It then
                     return (if Local.Kind = Macro_Binding
                             then Local.Macro
                             else Raven.Target.No_Macro);
                  end if;

                  return Target.Macro (Use_Site, Written);
               end;
            elsif not Found then
               --  As a name that is not a macro is resolved: a
               --  macro's body means the macros of the library it was
               --  written in, and what the body produced means the
               --  use site's first.

               if not Expanding then
                  return Target.Macro (Home, Name);
               elsif Hygienic then
                  return Target.Macro (Use_Site, Name);
               else
                  declare
                     Id : constant Raven.Target.Macro_Id :=
                            Target.Macro (Use_Site, Name);
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

      ---------------
      -- Head_Name --
      ---------------

      function Head_Name (F : Object) return Object is
         Found : Boolean;
         Ent   : Env_Entry;
      begin
         if not Is_Alias (F) then
            return F;
         end if;

         Find_Binding
           (Target.To_String (Raven.Objects.To_Symbol (F)), Found, Ent);
         return (if Found then F else Plain (F));
      end Head_Name;

      --------------
      -- Is_Alias --
      --------------

      function Is_Alias (Sym : Object) return Boolean
      is (Raven.Objects.Is_Symbol (Sym)
          and then Target.Alias_Library (Raven.Objects.To_Symbol (Sym)) /= 0);

      ------------
      -- Locate --
      ------------

      procedure Locate (Sym : Object) is
         Name : constant String :=
                  Target.To_String (Objects.To_Symbol (Sym));
      begin
         if Try_Lexical (Name) then
            return;
         end if;

         if not Is_Alias (Sym) then

            --  Nothing lexical holds the name, so a library does.

            Append_Reference (Sym);
            return;
         end if;

         --  A name a template wrote (#24), which means what it meant
         --  where the template was written: a binding of the alias
         --  itself, which is one the template made, and then a global
         --  of the macro's library -- whatever the caller has bound the
         --  name to.  After that, as it was before aliases, for what a
         --  macro written in a body means by its body's names and for a
         --  name the use site defines: bound here, then the use site's,
         --  then the macro's library, where it may be defined later.

         declare
            Written : constant Object := Plain (Sym);
            Text    : constant String :=
                        Target.To_String (Objects.To_Symbol (Written));
            Macro_Library : constant Raven.Target.Real_Library_Id :=
                              Alias_Home (Sym);
            Inner   : Objects.Symbol_Id :=
                        Target.Alias_Original (Objects.To_Symbol (Sym));
         begin
            --  An alias of an alias is a name a macro written by a
            --  template wrote, and a binding of any of them is the
            --  templates'.

            while Target.Alias_Library (Inner) /= 0 loop
               if Try_Lexical (Target.To_String (Inner)) then
                  return;
               end if;
               Inner := Target.Alias_Original (Inner);
            end loop;

            if Target.Binds (Macro_Library, Text) then
               Append_Reference_In (Macro_Library, Written);
            elsif Try_Lexical (Text) then
               null;
            elsif Target.Binds (Use_Site, Text) then
               Append_Reference_In (Use_Site, Written);
            else
               Append_Reference_In (Macro_Library, Written);
            end if;
         end;
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

      -----------
      -- Plain --
      -----------

      function Plain (Sym : Object) return Object is
         Id : Objects.Symbol_Id;
      begin
         if not Is_Alias (Sym) then
            return Sym;
         end if;

         Id := Objects.To_Symbol (Sym);
         while Target.Alias_Library (Id) /= 0 loop
            Id := Target.Alias_Original (Id);
         end loop;
         return Objects.To_Object (Id);
      end Plain;

      -----------------
      -- Try_Lexical --
      -----------------

      function Try_Lexical (Name : String) return Boolean is
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
                  return True;
               end if;
            end;
            if Frame.Kind = Run_Time_Frame then
               I := @ + 1;
            end if;
         end loop;

         return False;
      end Try_Lexical;

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
                        Target.To_String
                          (Raven.Objects.To_Symbol (Plain (Sym)));
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
