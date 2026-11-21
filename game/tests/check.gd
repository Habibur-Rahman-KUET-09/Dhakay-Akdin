## Base for test files: methods named test_* are run by run_tests.gd.
extends RefCounted

var current := ""
var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append("%s: %s" % [current, what])


func eq(actual, expected, what := "") -> void:
	if actual != expected:
		failures.append("%s: %s expected %s, got %s" % [current, what, expected, actual])


func near(actual: float, expected: float, what := "", tol := 1e-6) -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: %s expected %s, got %s" % [current, what, expected, actual])
