extends GutTest


func test_every_speaker_has_a_name_and_portrait() -> void:
	var speakers: Array[SpeakerDef] = []
	speakers.append_array(Content.dealers())
	speakers.append_array(Content.characters())
	speakers.append_array(Content.players())
	for speaker in speakers:
		assert_false(speaker.display_name.is_empty(), String(speaker.id))
		assert_not_null(speaker.portrait, String(speaker.id))
		assert_false(speaker.title().is_empty(), String(speaker.id))
		if speaker.talk_portrait != null:
			assert_eq(speaker.talk_portrait.get_size(), speaker.portrait.get_size(), "%s talk frame size" % speaker.id)


func test_players_can_be_picked() -> void:
	assert_eq(Content.players().size(), 3)
	assert_not_null(Content.player(RunState.DEFAULT_PLAYER))
	assert_eq(Content.player(&"nobody"), Content.players()[0], "unknown ids fall back to a real player")
	for player in Content.players():
		assert_false(player.intro_line.is_empty(), String(player.id))


func test_speaker_lookup_covers_every_kind() -> void:
	assert_true(Content.speaker(&"officer") is CharacterDef)
	assert_true(Content.speaker(&"nadia") is DealerDef)
	assert_true(Content.speaker(&"mira") is PlayerDef)
	assert_null(Content.speaker(&""))


func test_event_speakers_exist() -> void:
	for event in Content.events():
		if not event.speaker.is_empty():
			assert_not_null(Content.character(event.speaker), "%s speaker %s" % [event.id, event.speaker])


func test_encounter_speakers_exist() -> void:
	for speaker_id in [Encounters.BEAT_OFFICER, Encounters.RAID_LEAD, Encounters.COLLECTOR, Loan.LENDER]:
		assert_not_null(Content.character(speaker_id), String(speaker_id))


func test_street_characters_have_something_to_say() -> void:
	for character in Content.characters():
		assert_false(character.line.is_empty(), String(character.id))
		assert_false(character.blurb.is_empty(), String(character.id))
