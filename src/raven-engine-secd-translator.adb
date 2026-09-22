with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Hash_Case_Insensitive;
with Ada.Text_IO;
with Raven.Instructions;
with Raven.Objects;
with Raven.Target;

package body Raven.Engine.SECD.Translator is

   use Raven.Instructions;
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

   package Macro_Id_Lists is
     new Ada.Containers.Doubly_Linked_Lists
       (Raven.Target.Real_Macro_Id, Raven.Target."=");

   type Instance is new Raven.Translator.Abstraction with
      record
         Current : Positive := 1;
         Code    : Object_List_Vectors.Vector;
      end record;

   overriding procedure Translate
     (This   : in out Instance;
      Target : Raven.Target.Reference);

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
     (This   : in out Instance;
      Target : Raven.Target.Reference)
   is
      Env : Env_Lists.List;

      --  Global definitions this form has displaced.  They are given
      --  back only once the form has been emitted: until Emit runs, a
      --  constant lifted out of a macro body sits in This.Code, where
      --  the collector cannot see it.

      Pending_Release : Macro_Id_Lists.List;

      procedure Bind_Macro
        (Name : String;
         Id   : Raven.Target.Real_Macro_Id);

      procedure Build_Env
        (Args : Object);

      procedure Close_Scope;

      procedure Compile_QQ
        (Template : Object);

      procedure Emit (Level : Positive);

      procedure Find_Binding
        (Name  : String;
         Found : out Boolean;
         Ent   : out Env_Entry);

      procedure Go
        (X : Object);

      function Head_Macro
        (F : Object)
         return Raven.Target.Macro_Id;

      procedure Locate (Sym : Object);

      procedure Nested
        (X    : Object;
         Last : Instruction);

      procedure Nested_Sequence
        (X    : Object;
         Last : Instruction);

      procedure Open_Scope;

      procedure Release_Later
        (Id : Raven.Target.Real_Macro_Id);

      procedure Undefine_Macro
        (Sym : Object);

      S_Atom              : constant Object := Target.To_Symbol ("atom?");
      S_Begin             : constant Object := Target.To_Symbol ("begin");
      S_Car               : constant Object := Target.To_Symbol ("car");
      S_Cdr               : constant Object := Target.To_Symbol ("cdr");
      S_Cons              : constant Object := Target.To_Symbol ("cons");
      S_Define            : constant Object := Target.To_Symbol ("define");
      S_Define_Macro      : constant Object := Target.To_Symbol ("define-macro");
      S_Eq                : constant Object := Target.To_Symbol ("raven-eq?");
      S_Pair              : constant Object := Target.To_Symbol ("pair?");
      S_Quasiquote        : constant Object := Target.To_Symbol ("quasiquote");
      S_Set               : constant Object := Target.To_Symbol ("set!");
      S_Unquote           : constant Object := Target.To_Symbol ("unquote");
      S_Unquote_Splicing  : constant Object := Target.To_Symbol ("unquote-splicing");
      Indent   : Natural := 0;

      ----------------
      -- Bind_Macro --
      ----------------

      procedure Bind_Macro
        (Name : String;
         Id   : Raven.Target.Real_Macro_Id)
      is
         Frame : constant Env_Lists.Reference_Type :=
                   Env.Reference (Env.Last);
      begin
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
      begin
         --  The region is finished, so nothing can name a macro it
         --  defined any more, but the definition is not given back.  A
         --  region scoped macro feeds the translation it appears in, and
         --  the constants lifted out of its body sit in This.Code, which
         --  the collector cannot see: releasing it here, or even after
         --  the whole form is emitted, lets objects the translation
         --  still depends on be collected.  Until the code lists are a
         --  root, these definitions have to stay alive.

         Env.Delete_Last;
      end Close_Scope;

      ----------------
      -- Compile_QQ --
      ----------------

      procedure Compile_QQ (Template : Object) is
         use Raven.Objects;
      begin
         if Is_Atom (Template) then
            This.Append (LDC);
            This.Append (Template);
         else
            declare
               Head : constant Object := Target.Car (Template);
               Tail : constant Object := Target.Cdr (Template);
            begin
               if Head = S_Unquote then
                  Go (Target.Car (Tail));
               elsif Is_Pair (Head)
                 and then Target.Car (Head) = S_Unquote_Splicing
               then
                  Compile_QQ (Tail);
                  Go (Target.Cadr (Head));
                  This.Append (APPEND);
               else
                  Compile_QQ (Tail);
                  Compile_QQ (Head);
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
               elsif X = Raven.Objects.To_Object (LD) then
                  Target.Push (X);
                  Count := Count + 1;
                  Next (Position);
                  if Objects.Is_Symbol (Element (Position)) then
                     Target.Push (Element (Position));
                  elsif Objects.Is_Integer (Element (Position))
                    and then Has_Element (Next (Position))
                    and then Objects.Is_Integer (Element (Next (Position)))
                  then
                     Target.Push (Element (Position));
                     Next (Position);
                     Target.Push (Element (Position));
                     Target.Cons;
                  else
                     raise Constraint_Error with
                     "emit: invalid argument to emit: "
                       & Show_Code (This.Code (Level), Target);
                  end if;
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
        (X     : Object)
      is
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
         if Raven.Objects.Is_Atom (X) then
            if Raven.Objects.Is_Symbol (X) then
               This.Append (LD);
               Locate (X);
            else
               This.Append (LDC);
               This.Append (X);
            end if;
         elsif Raven.Objects.Is_Pair (X) then
            declare
               F     : constant Object := Target.Car (X);
               A     : constant Object := Target.Cdr (X);
               Macro : constant Raven.Target.Macro_Id := Head_Macro (F);
            begin
               if F = Raven.Objects.Quote then
                  Load_Constant (Target.Cadr (X));
               elsif F = Raven.Objects.If_Obj then
                  declare
                     Args : Object := A;
                  begin
                     Go (Target.Car (Args));
                     This.Append (SEL);
                     Args := Target.Cdr (Args);
                     Nested (Target.Car (Args), JOIN);
                     if Objects.Is_Pair (Args) then
                        Nested (Target.Cadr (Args), JOIN);
                     else
                        Nested (Objects.Nil, JOIN);
                     end if;
                  end;
               elsif F = S_Begin then
                  declare
                     use Raven.Objects;
                     Arg : Object := A;
                  begin
                     while Is_Pair (Arg) loop
                        Go (Target.Car (Arg));
                        Arg := Target.Cdr (Arg);
                        if Is_Pair (Arg) then
                           This.Append (DROP);
                        end if;
                     end loop;
                  end;
               elsif F = Raven.Objects.Lambda then
                  Build_Env (Target.Car (A));
                  This.Append (LDF);
                  declare
                     Es : constant Object := Target.Cdr (A);
                  begin
                     Nested_Sequence (Es, RTN);
                  end;
                  Close_Scope;
               elsif F = S_Set then
                  if not Raven.Objects.Is_Symbol (Target.Car (A)) then
                     raise Raven.Target.Translation_Error with
                       "set! requires a symbol as its first argument";
                  end if;
                  Go (Target.Cadr (A));
                  This.Append (ST);
                  Locate (Target.Car (A));
               elsif F = S_Eq then
                  Go (Target.Car (A));
                  Go (Target.Cadr (A));
                  This.Append (EQ);
               elsif F = S_Car then
                  Go (Target.Car (A));
                  This.Append (CAR);
               elsif F = S_Cdr then
                  Go (Target.Car (A));
                  This.Append (CDR);
               elsif F = S_Cons then
                  Go (Target.Cadr (A));
                  Go (Target.Car (A));
                  This.Append (CONS);
               elsif F = S_Atom then
                  Go (Target.Car (A));
                  This.Append (ATOM);
               elsif F = S_Pair then
                  Go (Target.Car (A));
                  This.Append (PAIR);
               elsif F = S_Quasiquote then
                  Compile_QQ (Target.Car (A));
               elsif F = S_Define then
                  if Raven.Objects.Is_Symbol (Target.Car (A)) then
                     Undefine_Macro (Target.Car (A));
                     Go (Target.Cadr (A));
                     This.Append (DFN);
                     This.Append (Target.Car (A));
                  elsif Raven.Objects.Is_Pair (Target.Car (A)) then
                     Undefine_Macro (Target.Caar (A));
                     Build_Env (Target.Cdar (A));
                     This.Append (LDF);
                     declare
                        Es : constant Object := Target.Cdr (A);
                     begin
                        Nested_Sequence (Es, RTN);
                     end;
                     Close_Scope;
                     This.Append (DFN);
                     This.Append (Target.Caar (A));
                  else
                     raise Program_Error with "invalid define";
                  end if;
               elsif F = S_Define_Macro then
                  if not Raven.Objects.Is_Pair (Target.Car (A))
                    or else not Raven.Objects.Is_Symbol (Target.Caar (A))
                  then
                     raise Raven.Target.Translation_Error with
                       "define-macro: first argument must be (name params ...)";
                  end if;
                  declare
                     Name_Sym   : constant Object := Target.Caar (A);
                     Name       : constant String :=
                                    Target.To_String
                                      (Raven.Objects.To_Symbol (Name_Sym));
                     Params     : constant Object := Target.Cdar (A);
                     Macro_Body : constant Object := Target.Cdr (A);
                     Id         : constant Raven.Target.Real_Macro_Id :=
                                    Target.Store_Macro (Params, Macro_Body);
                  begin
                     --  The definition belongs to the region being
                     --  translated.  Only a form at top level, where
                     --  there is no enclosing region, defines globally.

                     if Env.Is_Empty then
                        Undefine_Macro (Name_Sym);
                        Target.Define_Global_Macro (Name, Id);
                     else
                        Bind_Macro (Name, Id);
                     end if;
                     This.Append (LDC);
                     This.Append (Name_Sym);
                  end;
               else
                  if Macro /= Raven.Target.No_Macro then
                     declare
                        Params          : Object;
                        Macro_Body_Obj  : Object;
                        Old_Current     : constant Positive := This.Current;
                        Expansion_Level : Positive;
                     begin
                        Target.Get_Macro (Macro, Params, Macro_Body_Obj);
                        This.Code.Append (Object_Lists.Empty_List);
                        Expansion_Level := This.Code.Last_Index;
                        This.Current    := Expansion_Level;
                        Load_Macro_Args (A);
                        Build_Env (Params);
                        This.Append (LDF);
                        Nested_Sequence (Macro_Body_Obj, RTN);
                        Close_Scope;
                        This.Append (AP);
                        This.Append (STOP);
                        This.Current := Old_Current;
                        Emit (Expansion_Level);
                        Target.Execute;
                        Go (Target.Pop);
                     end;
                  else
                     declare
                        procedure Compile_Args (Args : Object);

                        ------------------
                        -- Compile_Args --
                        ------------------

                        procedure Compile_Args (Args : Object) is
                        begin
                           if Args = Objects.Nil then
                              This.Append (LDC);
                              This.Append (Objects.Nil);
                           else
                              Compile_Args (Target.Cdr (Args));
                              Go (Target.Car (Args));
                              This.Append (CONS);
                           end if;
                        end Compile_Args;

                     begin
                        Compile_Args (Target.Cdr (X));
                        Go (F);
                        This.Append (AP);
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
               return Target.Global_Macro (Name);
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
         This.Append (Sym);
      end Locate;

      ------------
      -- Nested --
      ------------

      procedure Nested
        (X    : Object;
         Last : Instruction)
      is
         Old_Level : constant Natural := This.Current;
         New_Level : Natural;
      begin
         This.Code.Append (Object_Lists.Empty_List);
         This.Current := This.Code.Last_Index;
         New_Level := This.Current;
         Open_Scope;
         Go (X);
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
         Last : Instruction)
      is
         use Raven.Objects;
         Old_Level : constant Natural := This.Current;
         New_Level : Natural;
         It        : Object := X;
      begin
         This.Code.Append (Object_Lists.Empty_List);
         This.Current := This.Code.Last_Index;
         New_Level := This.Current;
         Open_Scope;
         while Is_Pair (It) loop
            Go (Target.Car (It));
            It := Target.Cdr (It);
            if Is_Pair (It) then
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

      -------------------
      -- Release_Later --
      -------------------

      procedure Release_Later
        (Id : Raven.Target.Real_Macro_Id)
      is
      begin
         Pending_Release.Append (Id);
      end Release_Later;

      --------------------
      -- Undefine_Macro --
      --------------------

      procedure Undefine_Macro (Sym : Object) is
      begin
         --  Defining a name takes it back from any macro that held it,
         --  which is the only way to undefine one.

         if Env.Is_Empty
           and then Raven.Objects.Is_Symbol (Sym)
         then
            declare
               Name : constant String :=
                        Target.To_String (Raven.Objects.To_Symbol (Sym));
               Old  : constant Raven.Target.Macro_Id :=
                        Target.Global_Macro (Name);
            begin
               if Old /= Raven.Target.No_Macro then
                  Release_Later (Old);
                  Target.Undefine_Global_Macro (Name);
               end if;
            end;
         end if;
      end Undefine_Macro;

   begin
      This.Code.Append (Object_Lists.Empty_List);
      Go (Target.Pop);
      This.Append (STOP);
      Emit (1);

      --  Emit has pushed every object the code refers to onto the
      --  machine's stack, so the definitions dropped along the way are
      --  no longer holding anything up.

      for Id of Pending_Release loop
         Target.Release_Macro (Id);
      end loop;
   exception
      when E : others =>
         for Id of Pending_Release loop
            Target.Release_Macro (Id);
         end loop;
         Ada.Text_IO.Put_Line (Ada.Exceptions.Exception_Message (E));
         for I in 1 .. This.Code.Last_Index loop
            Ada.Text_IO.Put (I'Image);
            Ada.Text_IO.Set_Col (5);
            Ada.Text_IO.Put_Line (Show_Code (This.Code (I), Target));
         end loop;
   end Translate;

end Raven.Engine.SECD.Translator;
