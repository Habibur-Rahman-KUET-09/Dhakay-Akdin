## The Dhaka card album (cards.gd).
extends "res://tests/check.gd"

const Cards = preload("res://scripts/rules/cards.gd")
const Balance = preload("res://scripts/rules/balance.gd")


func test_the_album_has_four_sets_of_six() -> void:
	eq(Cards.sets().size(), 4, "four sets")
	eq(Cards.count(), 24, "24 cards")
	eq(Cards.set_for("rickshaw"), "places", "the rickshaw finds places")
	eq(Cards.set_for("fuchka"), "food", "the fuchka cart, food")
	eq(Cards.set_for("boat"), "rides", "the boat, rides")
	eq(str(Cards.card("sadarghat").set), "places", "a card knows its set")


func test_new_cards_repeats_and_a_whole_set() -> void:
	var b := Balance.new()
	var save := {"tara": 0}
	var got := Cards.give(save, b, "shahbag")
	check(got.new, "a new card")
	eq(int(save.tara), 0, "no stars for a new one")
	got = Cards.give(save, b, "shahbag")
	check(not got.new, "the same again")
	eq(int(save.tara), 1, "a repeat turns into a star")
	for id in ["sadarghat", "ahsan_manzil", "mirpur10", "dhanmondi_lake"]:
		Cards.give(save, b, id)
	got = Cards.give(save, b, "karwan_bazar")
	eq(str(got.set_done), "places", "the set is whole")
	eq(int(save.tara), 1 + 15, "and pays 15 stars")


func test_a_day_draws_from_its_set_or_the_festival() -> void:
	var b := Balance.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var save := {}
	var got := Cards.draw(save, b, "tea", "", rng)
	eq(str(Cards.card(str(got.id)).set), "food", "tea: a food card")
	got = Cards.draw(save, b, "tea", "boishakh", rng)
	eq(str(got.id), "boishakh", "Pohela Boishakh: its own card")
	eq(Cards.draw(save, b, "night_unknown", "", rng), {}, "no set, no card")
