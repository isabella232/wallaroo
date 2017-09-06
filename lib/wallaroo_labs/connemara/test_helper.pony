/*

Copyright (C) 2016-2017, Sendence LLC
Copyright (C) 2016-2017, The Pony Developers
Copyright (c) 2014-2015, Causality Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

interface ITest
  fun apply() ?

class val TestHelper
  """
  Per unit test class that provides control, logging and assertion functions.

  Each unit test is given a TestHelper when it is run. This is val and so can
  be passed between methods and actors within the test without restriction.

  The assertion functions check the relevant condition and mark the test as a
  failure if appropriate. The success or failure of the condition is reported
  back as a Bool which can be checked if a different code path is needed when
  that condition fails.

  All assert functions take an optional message argument. This is simply a
  string that is printed as part of the error message when the condition fails.
  It is intended to aid identifying what failed.
  """

  let _runner: _TestRunner
  let env: Env

  new val _create(runner: _TestRunner, env': Env) =>
    """
    Create a new TestHelper.
    """
    env = env'
    _runner = runner

  fun log(msg: String, verbose: Bool = false) =>
    """
    Log the given message.

    The verbose parameter allows messages to be printed only when the --verbose
    command line option is used. For example, by default assert failures are
    logged, but passes are not. With --verbose both passes and fails are
    reported.

    Logs are printed one test at a time to avoid interleaving log lines from
    concurrent tests.
    """
    _runner.log(msg, verbose)

  fun fail(msg: String = "Test failed") =>
    """
    Flag the test as having failed.
    """
    _runner.fail(msg)

  fun assert_true(actual: Bool, msg: String = "", loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the given expression is true.
    """
    if not actual then
      fail(_format_loc(loc) + "Assert true failed. " + msg)
      return false
    end
    log(_format_loc(loc) + "Assert true passed. " + msg, true)
    true

  fun assert_false(actual: Bool, msg: String = "", loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the given expression is false.
    """
    if actual then
      fail(_format_loc(loc) + "Assert false failed. " + msg)
      return false
    end
    log(_format_loc(loc) + "Assert false passed. " + msg, true)
    true

  fun assert_error(test: ITest box, msg: String = "", loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the given test function throws an error when run.
    """
    try
      test()
      fail(_format_loc(loc) + "Assert error failed. " + msg)
      false
    else
      log(_format_loc(loc) + "Assert error passed. " + msg, true)
      true
    end

  fun assert_no_error(
    test: ITest box,
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the gived test function does not throw an error when run.
    """
    try
      test()
      log(_format_loc(loc) + "Assert no error passed. " + msg, true)
      true
    else
      fail(_format_loc(loc) + "Assert no error failed. " + msg)
      true
    end

  fun assert_is[A](
    expect: A,
    actual: A,
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the 2 given expressions resolve to the same instance
    """
    _check_is[A]("is", consume expect, consume actual, msg, loc)

  fun _check_is[A](
    check: String,
    expect: A,
    actual: A,
    msg: String,
    loc: SourceLoc)
    : Bool
  =>
    """
    Check that the 2 given expressions resolve to the same instance
    """
    if expect isnt actual then
      fail(_format_loc(loc) + "Assert " + check + " failed. " + msg
        + " Expected (" + (digestof expect).string() + ") is ("
        + (digestof actual).string() + ")")
      return false
    end

    log(
      _format_loc(loc) + "Assert " + check + " passed. " + msg
        + " Got (" + (digestof expect).string() + ") is ("
        + (digestof actual).string() + ")",
      true)
    true

  fun assert_eq[A: (Equatable[A] #read & Stringable #read)]
    (expect: A, actual: A, msg: String = "", loc: SourceLoc = __loc): Bool
  =>
    """
    Assert that the 2 given expressions are equal.
    """
    _check_eq[A]("eq", expect, actual, msg, loc)

  fun _check_eq[A: (Equatable[A] #read & Stringable)]
    (check: String, expect: A, actual: A, msg: String, loc: SourceLoc)
    : Bool
  =>
    """
    Check that the 2 given expressions are equal.
    """
    if expect != actual then
      fail(_format_loc(loc) + "Assert " + check + " failed. " + msg
        + " Expected (" + expect.string() + ") == (" + actual.string() + ")")
      return false
    end

    log(_format_loc(loc) + "Assert " + check + " passed. " + msg
      + " Got (" + expect.string() + ") == (" + actual.string() + ")", true)
    true

  fun assert_isnt[A](
    not_expect: A,
    actual: A,
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the 2 given expressions resolve to different instances.
    """
    _check_isnt[A]("isn't", consume not_expect, consume actual, msg, loc)

  fun _check_isnt[A](
    check: String,
    not_expect: A,
    actual: A,
    msg: String,
    loc: SourceLoc)
    : Bool
  =>
    """
    Check that the 2 given expressions resolve to different instances.
    """
    if not_expect is actual then
      fail(_format_loc(loc) + "Assert " + check + " failed. " + msg
        + " Expected (" + (digestof not_expect).string() + ") isnt ("
        + (digestof actual).string() + ")")
      return false
    end

    log(
      _format_loc(loc) + "Assert " + check + " passed. " + msg
        + " Got (" + (digestof not_expect).string() + ") isnt ("
        + (digestof actual).string() + ")",
      true)
    true

  fun assert_ne[A: (Equatable[A] #read & Stringable #read)]
    (not_expect: A, actual: A, msg: String = "", loc: SourceLoc = __loc): Bool
  =>
    """
    Assert that the 2 given expressions are not equal.
    """
    _check_ne[A]("ne", not_expect, actual, msg, loc)

  fun _check_ne[A: (Equatable[A] #read & Stringable)]
    (check: String, not_expect: A, actual: A, msg: String, loc: SourceLoc)
    : Bool
  =>
    """
    Check that the 2 given expressions are not equal.
    """
    if not_expect == actual then
      fail(_format_loc(loc) + "Assert " + check + " failed. " + msg
        + " Expected (" + not_expect.string() + ") != (" + actual.string()
        + ")")
      return false
    end

    log(
      _format_loc(loc) + "Assert " + check + " passed. " + msg
        + " Got (" + not_expect.string() + ") != (" + actual.string() + ")",
      true)
    true

  fun assert_array_eq[A: (Equatable[A] #read & Stringable #read)](
    expect: ReadSeq[A],
    actual: ReadSeq[A],
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the contents of the 2 given ReadSeqs are equal.
    """
    var ok = true

    if expect.size() != actual.size() then
      ok = false
    else
      try
        var i: USize = 0
        while i < expect.size() do
          if expect(i) != actual(i) then
            ok = false
            break
          end

          i = i + 1
        end
      else
        ok = false
      end
    end

    if not ok then
      fail(_format_loc(loc) + "Assert EQ failed. " + msg + " Expected ("
        + _print_array[A](expect) + ") == (" + _print_array[A](actual) + ")")
      return false
    end

    log(
      _format_loc(loc) + "Assert EQ passed. " + msg + " Got ("
        + _print_array[A](expect) + ") == (" + _print_array[A](actual) + ")",
      true)
    true

  fun assert_array_eq_unordered[A: (Equatable[A] #read & Stringable #read)](
    expect: ReadSeq[A],
    actual: ReadSeq[A],
    msg: String = "",
    loc: SourceLoc = __loc)
    : Bool
  =>
    """
    Assert that the contents of the 2 given ReadSeqs are equal ignoring order.
    """
    try
      let missing = Array[box->A]
      let consumed = Array[Bool].init(false, actual.size())
      for e in expect.values() do
        var found = false
        var i: USize = -1
        for a in actual.values() do
          i = i + 1
          if consumed(i) then continue end
          if e == a then
            consumed.update(i, true)
            found = true
            break
          end
        end
        if not found then
          missing.push(e)
        end
      end

      let extra = Array[box->A]
      for (i, c) in consumed.pairs() do
        if not c then extra.push(actual(i)) end
      end

      if (extra.size() != 0) or (missing.size() != 0) then
        fail(
          _format_loc(loc) + "Assert EQ_UNORDERED failed. " + msg
            + " Expected (" + _print_array[A](expect) + ") == ("
            + _print_array[A](actual) + "):"
            + "\nMissing: " + _print_array[box->A](missing)
            + "\nExtra: " + _print_array[box->A](extra))
        return false
      end
      log(
        _format_loc(loc) + "Assert EQ_UNORDERED passed. " + msg + " Got ("
          + _print_array[A](expect) + ") == (" + _print_array[A](actual) + ")",
        true)
      true
    else
      fail("Assert EQ_UNORDERED failed from an internal error.")
      false
    end

  fun _format_loc(loc: SourceLoc): String =>
    loc.file() + ":" + loc.line().string() + ": "

  fun _print_array[A: Stringable #read](array: ReadSeq[A]): String =>
    """
    Generate a printable string of the contents of the given readseq to use in
    error messages.
    """
    "[len=" + array.size().string() + ": " + ", ".join(array) + "]"

  fun long_test(timeout: U64) =>
    """
    Indicate that this is a long running test that may continue after the
    test function exits.
    Once this function is called, complete() must be called to finish the test,
    unless a timeout occurs.
    The timeout is specified in nanseconds.
    """
    _runner.long_test(timeout)

  fun complete(success: Bool) =>
    """
    MUST be called by each long test to indicate the test has finished, unless
    a timeout occurs.

    The "success" parameter specifies whether the test succeeded. However if
    any asserts fail the test will be considered a failure, regardless of the
    value of this parameter.

    Once this is called tear_down() may be called at any time.
    """
    _runner.complete(success)

  fun expect_action(name: String) =>
    """
    Can be called in a long test to set up expectations for one or more actions
    that, when all completed, will complete the test.

    This pattern is useful for cases where you have multiple things that need
    to happen to complete your test, but don't want to have to collect them
    all yourself into a single actor that calls the complete method.

    The order of calls to expect_action don't matter - the actions may be
    completed in any other order to complete the test.
    """
    _runner.expect_action(name)

  fun complete_action(name: String) =>
    """
    MUST be called for each action expectation that was set up in a long test
    to fulfill the expectations. Any expectations that are still outstanding
    when the long test timeout runs out will be printed by name when it fails.

    Completing all outstanding actions is enough to finish the test. There's no
    need to also call the complete method when the actions are finished.

    Calling the complete method will finish the test immediately, without
    waiting for any outstanding actions to be completed.
    """
    _runner.complete_action(name, true)

  fun fail_action(name: String) =>
    """
    Call to fail an action, which will also cause the entire test to fail
    immediately, without waiting the rest of the outstanding actions.

    The name of the failed action will be included in the failure output.

    Usually the action name should be an expected action set up by a call to
    expect_action, but failing unexpected actions will also fail the test.
    """
    _runner.complete_action(name, false)

  fun dispose_when_done(disposable: DisposableActor) =>
    """
    Pass a disposable actor to be disposed of when the test is complete.
    The actor will be disposed no matter whether the test succeeds or fails.

    If the test is already tearing down, the actor will be disposed immediately.
    """
    _runner.dispose_when_done(disposable)