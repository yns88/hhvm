<?php

class A {
  function t($a, $arr) {
  }
}
class B extends A {
  function t($a, $arr) {
    var_dump($a);
    $arr['hello'] = $a;
    var_dump($a);
  }
}
function f() {
  return new B();
}
function test() {
  $v = 100;
  $arr['hello'] = $v;
  $a = new B();
  $a->t($arr['hello'], $arr);
}
function test2(&$a, $b) {
  $a = $b;
}

<<__EntryPoint>>
function main_1090() {
test();
$arr = array('hello' => 1);
$x = &$arr['hello'];
$arr['hello'] = $x;
var_dump($arr);
$v = 10;
test2(&$v, $v);
var_dump($v);
}
