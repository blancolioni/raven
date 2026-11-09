# raven
R7RS small library

## Embedding raven

An Ada program embeds raven by withing `Raven` and creating a VM with
`New_VM`. The VM talks to the host through 16 numbered *slots*. The
result of `Evaluate` goes into slot 1. A foreign function finds its
arguments in slots 1 .. N and leaves its result in slot 1.

```ada
with Raven;

package Host_Functions is

   --  (host-double n): a Scheme procedure written in Ada.  A foreign
   --  function must be declared at library level, so that
   --  'Access is allowed on it.
   procedure Double (VM : Raven.Raven_VM);

end Host_Functions;

package body Host_Functions is

   procedure Double (VM : Raven.Raven_VM) is
      N : constant Integer := VM.Get_Slot (1);
   begin
      VM.Set_Slot (1, 2 * N);
   end Double;

end Host_Functions;
```

```ada
with Ada.Text_IO;
with Raven;
with Host_Functions;

procedure Host is

   use Raven;

   VM : Raven_VM := New_VM;

begin
   VM.Bind_Foreign_Function ("host-double", Host_Functions.Double'Access, 1);

   --  Evaluate an expression; its value is left in slot 1.
   VM.Evaluate ("(define (square x) (* x x))");
   VM.Evaluate ("(host-double (square 7))");
   Ada.Text_IO.Put_Line (VM.Show_Slot (1));            --  98

   --  Read a slot as an Ada value, checking its kind first.
   VM.Evaluate ("(string-append ""hello, "" ""world"")");
   if VM.Kind (1) = String_Kind then
      Ada.Text_IO.Put_Line (String'(VM.Get_Slot (1)));  --  hello, world
   end if;

   --  Bind a handle to a global name; evaluating the handle puts the
   --  name's current value in slot 1.
   VM.Evaluate ("(define counter 41)");
   VM.Evaluate ("(set! counter (+ counter 1))");
   declare
      Counter : Handle := VM.Bind_Name ("counter");
   begin
      VM.Evaluate (Counter);
      Ada.Text_IO.Put_Line (Integer'Image (VM.Get_Slot (1)));  --  42
      VM.Release (Counter);
   end;

   --  Call a Scheme procedure from Ada: the procedure goes in a slot and
   --  its arguments in the slots after it.  The answer replaces the
   --  procedure.
   VM.Evaluate ("square");
   VM.Set_Slot (2, 12);
   VM.Slot_Apply (1, 1);
   Ada.Text_IO.Put_Line (VM.Show_Slot (1));            --  144

   Close_VM (VM);
end Host;
```

Notes:

- `New_VM` takes optional arguments: an `IO_Reference` that redirects
  output, errors and input (the default is the terminal), a
  `Library_Path` for the Scheme standard library, and a `Heap_Size`.
- The Scheme standard library is found with the Alire `resources`
  crate. When the program is run under Alire (`alr run`, `alr exec`),
  `RAVEN_ALIRE_PREFIX` is set and the library is read from
  `$RAVEN_ALIRE_PREFIX/share/raven/libraries`. When it isn't run under
  Alire, the library is read from `share/raven/libraries` under the
  install prefix (the parent of the executable's directory). Pass
  `Library_Path` to use a different location.
- An error in evaluated code raises an Ada exception out of `Evaluate`.
  The VM is still usable after that.
- Every handle keeps its object alive until it is passed to `Release`.
- A raw `Object` can be moved by any operation that allocates. Keep
  values in slots or handles, not in Ada variables.
- `Raven.Foreign_Values` wraps host data as Scheme values. See
  `raven_tests/src/probe_host.adb` for an example.
