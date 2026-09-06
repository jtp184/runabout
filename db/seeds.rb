[
  [ "TNG", "The Next Generation", "classic", [ "TNG", "The Next Generation" ], 655 ],
  [ "DS9", "Deep Space Nine", "nemesis-blue", [ "DS9", "Deep Space Nine" ], 580 ],
  [ "VOY", "Voyager", "voyager", [ "VOY", "Voyager" ], 1855 ],
  [ "TOS", "The Original Series", "classic", [ "TOS", "Original Series", "" ], 253 ],
  [ "TAS", "The Animated Series", "classic", [ "TAS", "The Animated Series" ], 1992 ],
  [ "ENT", "Enterprise", "classic", [ "ENT", "Enterprise" ], 314 ],
  [ "DIS", "Discovery", "picard", [ "DIS", "DISCO", "Discovery" ], 67198 ],
  [ "PIC", "Picard", "picard", [ "PIC", "Picard" ], 85949 ],
  [ "LD", "Lower Decks", "lower-decks-padd", [ "LD", "Lower Decks" ], 85948 ],
  [ "SNW", "Strange New Worlds", "picard", [ "SNW", "Strange New Worlds" ], 103516 ],
  [ "PRO", "Prodigy", "classic", [ "PRO", "Prodigy" ], 106393 ],
  [ "ST", "Short Treks", "picard", [ "ST", "Short Treks" ], 82491 ],
  [ "FILM", "Star Trek films", "classic", [ "FILM", "Films" ], nil ]
].each do |code, name, theme, aliases, tmdb_id|
  Series.find_or_initialize_by(code: code).update!(name: name, theme: theme, aliases: aliases, tmdb_id: tmdb_id)
end
[
  [ "starships|spacecraft|.*-class ships", "Ship", 100 ],
  [ "natives|characters|personnel|scientists|officers|physicians|performers", "Character", 90 ],
  [ "species|lifeforms", "Species", 80 ],
  [ "planets|cities|locations|star systems|settlements", "Location", 70 ],
  [ "technology|devices|instruments|weapons|materials|computers", "Technology", 60 ],
  [ "culture|music|religion|food|beverages|art|organizations", "Culture", 50 ]
].each do |pattern, display_type, priority|
  ClassificationRule.find_or_initialize_by(pattern: pattern).update!(display_type: display_type, priority: priority)
end
Catalog.find_or_create_by!(id: 1)
PlayerState.current
