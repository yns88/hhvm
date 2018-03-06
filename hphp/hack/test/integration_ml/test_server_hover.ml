(**
 * Copyright (c) 2016, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

open Hh_core
open HoverService

module Test = Integration_test_base

let builtins = "<?hh // strict
class Awaitable<T> {}"

let class_members = "<?hh // strict
abstract class ClassMembers {
  public async function genDoStuff(): Awaitable<void> {}

  public string $public = 'public';
  protected string $protected = 'protected';
  private string $private = 'private';

  public static string $staticVar = 'staticVar';

  public abstract function abstractMethod(): string;

  public final function finalMethod(string $arg): void {}

  protected final static async function genLotsOfModifiers(): Awaitable<void> {}

  public async function exerciseClassMembers(): Awaitable<void> {
    await $this->genDoStuff();
//               ^18:18
    $this->public;
//         ^20:12
    $this->protected;
//         ^22:12
    $this->private;
//         ^24:12
    ClassMembers::$staticVar;
//                ^26:19
    $this->abstractMethod();
//         ^28:12
    $this->finalMethod(\"arg\");
//         ^30:12
    await ClassMembers::genLotsOfModifiers();
//        ^32:11        ^32:25
  }
}"

let class_members_cases = [
  ("class_members.php", 18, 18), [
    {
      snippet = "public async function genDoStuff(): Awaitable<void>";
      addendum = ["Full name: `ClassMembers::genDoStuff`"]
    }
  ];
  ("class_members.php", 20, 12), [
    {
      snippet = "public string ClassMembers::public";
      addendum = []
    };
  ];
  ("class_members.php", 22, 12), [
    {
      snippet = "protected string ClassMembers::protected";
      addendum = []
    };
  ];
  ("class_members.php", 24, 12), [
    {
      snippet = "private string ClassMembers::private";
      addendum = []
    };
  ];
  ("class_members.php", 26, 19), [
    {
      snippet = "public static string ClassMembers::staticVar";
      addendum = []
    };
  ];
  ("class_members.php", 28, 12), [
    {
      snippet = "public abstract function abstractMethod(): string";
      addendum = ["Full name: `ClassMembers::abstractMethod`"]
    }
  ];
  ("class_members.php", 30, 12), [
    {
      snippet = "public final function finalMethod(string $arg): void";
      addendum = ["Full name: `ClassMembers::finalMethod`"]
    };
  ];
  ("class_members.php", 32, 11), [
    {
      snippet = "abstract class ClassMembers";
      addendum = []
    };
  ];
  ("class_members.php", 32, 25), [
    {
      snippet = "protected final static async\n\
                 function genLotsOfModifiers(): Awaitable<void>";
      addendum = ["Full name: `ClassMembers::genLotsOfModifiers`"]
    };
  ];
]

let classname_call = "<?hh // strict
class ClassnameCall {
  static function foo(): int {
    return 0;
  }
}

function call_foo(): void {
  ClassnameCall::foo();
// ^9:4          ^9:18
}"

let classname_call_cases = [
  ("classname_call.php", 9, 4), [{
      snippet = "class ClassnameCall";
      addendum = []
    }];
  ("classname_call.php", 9, 18), [{
      snippet = "static function foo(): int";
      addendum = ["Full name: `ClassnameCall::foo`"]
    }];
]

let chained_calls = "<?hh // strict
class ChainedCalls {
  public function foo(): this {
    return $this;
  }
}

function test(): void {
  $myItem = new ChainedCalls();
  $myItem
    ->foo()
    ->foo()
    ->foo();
//     ^13:8
}"

let chained_calls_cases = [
  ("chained_calls.php", 13, 8), [
    {
      snippet = "public function foo(): ChainedCalls";
      addendum = ["Full name: `ChainedCalls::foo`"]
    };
  ];
]

let multiple_potential_types = "<?hh // strict
class C1 { public function foo(): int { return 5; } }
class C2 { public function foo(): string { return 's'; } }
function test_multiple_type(C1 $c1, C2 $c2, bool $cond): arraykey {
  $x = $cond ? $c1 : $c2;
  return $x->foo();
//        ^6:11^6:16
}"

let multiple_potential_types_cases = [
  ("multiple_potential_types.php", 6, 11), [{
      snippet = "(C1 | C2)";
      addendum = []
    }];
  ("multiple_potential_types.php", 6, 16), [
    {
      snippet = "((function(): string) | (function(): int))";
      addendum = []
    };
    {
      snippet = "((function(): string) | (function(): int))";
      addendum = []
    };
  ];
]

let classname_variable = "<?hh // strict
class ClassnameVariable {
  public static function foo(): void {}
}

function test_classname(): void {
  $cls = ClassnameVariable::class;
  $cls::foo();
// ^8:4  ^8:10
}"

let classname_variable_cases = [
  ("classname_variable.php", 8, 4), [{
      snippet = "classname<ClassnameVariable>";
      addendum = []
    }];

  (* TODO(wipi): make this return something useful. *)
  ("classname_variable.php", 8, 10), [{
      snippet = "_";
      addendum = []
    }];
]

let docblock = "<?hh // strict

// Multiline
// function
// doc block.
function queryDocBlocks(): void {
  DocBlock::doStuff();
//^7:3     ^7:13
  queryDocBlocks();
//^9:3
  DocBlock::preserveIndentation();
//          ^11:13
  DocBlock::leadingStarsAndMDList();
//          ^13:13
  DocBlock::manyLineBreaks();
//          ^15:13
  $x = new DocBlockOnClassButNotConstructor();
//         ^17:12
}

function docblockReturn(): DocBlockBase {
//                         ^21:28
  $x = new DocBlockBase();
//         ^23:12
  return new DocBlockDerived();
//           ^25:14
}

/* Class doc block.
   This
   doc
   block
   has
   multiple
   lines. */
class DocBlock {
  /** Method doc block with double star. */
  public static function doStuff(): void {}

  /** Multiline doc block with
      a certain amount of
          indentation
      we want to preserve. */
  public static function preserveIndentation(): void {}

  /** Multiline doc block with
    * leading stars, as well as
    *   * a Markdown list!
    * and we'd really like to preserve the Markdown list while getting rid of
    * the other stars. */
  public static function leadingStarsAndMDList(): void {}

  /**
   * This method has many line breaks, which
   *
   * someone might use if they wanted
   *
   * to have separate paragraphs
   *
   * in Markdown.
   */
  public static function manyLineBreaks(): void {}
}

/**
 * Class doc block for a class whose constructor doesn't have a doc block.
 */
final class DocBlockOnClassButNotConstructor {
  public function __construct() {}
}

/* DocBlockBase: class doc block. */
class DocBlockBase {
  /* DocBlockBase: constructor doc block. */
  public function __construct() {}
}

/* DocBlockDerived: extends a class with a constructor, but doesn't have one of
   its own. */
class DocBlockDerived extends DocBlockBase {}
"

let docblockCases = [
  ("docblock.php", 7, 3), [
    {
      snippet = "class DocBlock";
      addendum = ["Class doc block.\n\
                   This\n\
                   doc\n\
                   block\n\
                   has\n\
                   multiple\n\
                   lines."]
    }
  ];
  ("docblock.php", 7, 13), [
    {
      snippet = "public static function doStuff(): void";
      addendum = ["Method doc block with double star."; "Full name: `DocBlock::doStuff`"]
    }
  ];
  ("docblock.php", 9, 3), [
    {
      snippet = "function queryDocBlocks(): void";
      addendum = ["Multiline\n\
                   function\n\
                   doc block."]
    }
  ];
  ("docblock.php", 11, 13), [
    {
      snippet = "public static function preserveIndentation(): void";
      addendum = ["Multiline doc block with
a certain amount of
    indentation
we want to preserve."; "Full name: `DocBlock::preserveIndentation`"]
    }
  ];
  ("docblock.php", 13, 13), [
    {
      snippet = "public static function leadingStarsAndMDList(): void";
      addendum = ["Multiline doc block with
leading stars, as well as
  * a Markdown list!
and we'd really like to preserve the Markdown list while getting rid of
the other stars."; "Full name: `DocBlock::leadingStarsAndMDList`"]
    }
  ];
  ("docblock.php", 15, 13), [
    {
      snippet = "public static function manyLineBreaks(): void";
      addendum = [
        "\n\
         This method has many line breaks, which\n\
         \n\
         someone might use if they wanted\n\
         \n\
         to have separate paragraphs\n\
         \n\
         in Markdown.\n";
      "Full name: `DocBlock::manyLineBreaks`"]
    }
  ];
  ("docblock.php", 17, 12), [
    {
      snippet =
        "public function __construct(): _";
      (* This is because we set `last_line` to 0 in Docblock_finder, but we
         can't get a proper `last_line` value without generating a TAST of the
         file that contains this class. I'll be fixing this in a later diff.
            -wipi *)
      addendum = [
        "\nClass doc block for a class whose constructor doesn't have a doc block.\n";
        "Full name: `DocBlockOnClassButNotConstructor::__construct`";
      ]
    }
  ];
  ("docblock.php", 21, 28), [
    {
      snippet = "DocBlockBase";
      addendum = ["DocBlockBase: class doc block."]
    }
  ];
  ("docblock.php", 23, 12), [
    {
      snippet = "public function __construct(): _";
      addendum = [
        "DocBlockBase: constructor doc block.";
        "Full name: `DocBlockBase::__construct`";
      ]
    }
  ];
  ("docblock.php", 25, 14), [
    {
      snippet = "public function __construct(): _";
      addendum = [
        "DocBlockBase: constructor doc block.";
        "Full name: `DocBlockBase::__construct`"]
    }
  ]
]

let files = [
  "builtins.php", builtins;
  "class_members.php", class_members;
  "classname_call.php", classname_call;
  "chained_calls.php", chained_calls;
  "classname_variable.php", classname_variable;
  "docblock.php", docblock;
]

let cases =
  docblockCases
  @ class_members_cases
  @ classname_call_cases
  @ chained_calls_cases
  @ classname_variable_cases

let () =
  let env = Test.setup_server () in
  let env = Test.setup_disk env files in

  Test.assert_no_errors env;

  List.iter cases ~f:begin fun ((file, line, col), expectedHover) ->
    let list_to_string hover_list =
      let string_list = hover_list |> List.map ~f:HoverService.string_of_result in
      let inner = match string_list |> List.reduce ~f:(fun a b -> a ^ "; " ^ b) with
        | None -> ""
        | Some s -> s
      in
      Printf.sprintf "%s:%d:%d: [%s]" file line col inner
    in
    let fn = ServerUtils.FileName ("/" ^ file) in
    let hover = ServerHover.go env (fn, line, col) in
    Test.assertEqual
      (list_to_string expectedHover)
      (list_to_string hover)
  end
