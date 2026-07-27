local voicing = require("core.voicing")

describe("voicing", function()
  describe("parsing the compact form", function()
    it("reads a fret per string, low E to high E", function()
      local v = assert(voicing.parse("x32010"))
      assert.are.same({ -1, 3, 2, 0, 1, 0 }, v.frets)
    end)

    it("round-trips back to the string it was parsed from", function()
      assert.are.equal("x32010", voicing.toText(assert(voicing.parse("x32010"))))
    end)

    it("distinguishes muted from open", function()
      local v = assert(voicing.parse("xx0232"))
      assert.are.equal(voicing.MUTED, v.frets[1])
      assert.are.equal(voicing.OPEN, v.frets[3])
    end)

    it("ignores surrounding whitespace and accepts a capital X", function()
      assert.are.equal("x32010", voicing.toText(assert(voicing.parse("  X32010 "))))
    end)
  end)

  describe("parsing the separated form", function()
    it("reads frets at and above the tenth, which the compact form cannot say", function()
      local v = assert(voicing.parse("10-12-12-11-10-10"))
      assert.are.same({ 10, 12, 12, 11, 10, 10 }, v.frets)
    end)

    it("round-trips back to the string it was parsed from", function()
      assert.are.equal("10-12-12-11-10-10",
        voicing.toText(assert(voicing.parse("10-12-12-11-10-10"))))
    end)

    it("reads muted and open strings alongside two-digit frets", function()
      -- A D barre shape at the tenth fret, with both outer strings muted.
      local v = assert(voicing.parse("x-x-12-14-15-14"))
      assert.are.same({ -1, -1, 12, 14, 15, 14 }, v.frets)
      assert.are.equal("x-x-12-14-15-14", voicing.toText(v))
    end)

    it("accepts spaces or commas where a guitarist wrote a hyphen", function()
      for _, text in ipairs({ "10 12 12 11 10 10", "10,12,12,11,10,10" }) do
        assert.are.equal("10-12-12-11-10-10", voicing.toText(assert(voicing.parse(text))))
      end
    end)

    it("reads a separated string of low frets, and gives back the compact form", function()
      assert.are.equal("x32010", voicing.toText(assert(voicing.parse("x-3-2-0-1-0"))))
    end)
  end)

  describe("rejecting invalid input", function()
    it("refuses a string with the wrong number of positions", function()
      local v, err = voicing.parse("x3201")
      assert.is_nil(v)
      assert.is_truthy(err:find("6"))
    end)

    it("refuses a character that is neither a fret nor a mute", function()
      local v, err = voicing.parse("x3201z")
      assert.is_nil(v)
      assert.is_truthy(err:find("z"))
    end)

    it("refuses an empty string", function()
      local v, err = voicing.parse("")
      assert.is_nil(v)
      assert.is_string(err)
    end)

    it("answers every prefix of a chord being typed without throwing", function()
      -- Slice 007 re-parses on each keystroke, so every intermediate state of
      -- both forms has to come back as either a voicing or a message. A prefix
      -- may well be a complete chord in its own right; what it may never do is
      -- raise, or hand back nothing at all.
      for _, text in ipairs({ "10-12-12-11-10-10", "x32010", "x-3-2-0-1-0" }) do
        for n = 1, #text do
          local typed = text:sub(1, n)
          local ok, v, err = pcall(voicing.parse, typed)
          assert.is_true(ok, "parsing '" .. typed .. "' threw: " .. tostring(v))
          assert.is_true(v ~= nil or type(err) == "string",
            "parsing '" .. typed .. "' refused without saying why")
        end
      end
    end)

    it("refuses a half-typed position rather than reading the gap as a string", function()
      -- `10-12-` is four positions typed and two to go, not six.
      local v, err = voicing.parse("10-12-")
      assert.is_nil(v)
      assert.is_truthy(err:find("6", 1, true))
    end)

    it("refuses a separated string with a token that is not a position", function()
      local v, err = voicing.parse("10-12-12-11-10-1o")
      assert.is_nil(v)
      assert.is_truthy(err:find("1o", 1, true))
    end)
  end)

  describe("framing", function()
    --- The nut is fret 1: the window starts at the top of the neck.
    local NUT = 1

    it("shows the nut for an open-position chord", function()
      assert.are.equal(NUT, voicing.baseFret(assert(voicing.parse("x32010"))))
    end)

    it("shows the nut for a low chord with no open strings", function()
      -- F barre shape at the first fret.
      assert.are.equal(NUT, voicing.baseFret(assert(voicing.parse("133211"))))
    end)

    it("starts the window at the lowest fretted fret for a high chord", function()
      assert.are.equal(7, voicing.baseFret(assert(voicing.parse("x79987"))))
    end)

    it("shows the nut for a chord with no fretted strings at all", function()
      assert.are.equal(NUT, voicing.baseFret(assert(voicing.parse("0x000x"))))
    end)

    it("shows the nut for every open chord a beginner learns", function()
      for name, text in pairs({
        E = "022100", A = "x02220", D = "xx0232",
        G = "320003", C = "x32010", Am = "x02210", Em = "022000",
      }) do
        assert.are.equal(NUT, voicing.baseFret(assert(voicing.parse(text, name))), name)
      end
    end)

    it("shows the nut for a barre shape low enough to reach it", function()
      for name, text in pairs({
        F = "133211", ["Bb"] = "x13331", B = "x24442", ["F#m"] = "244222",
      }) do
        assert.are.equal(NUT, voicing.baseFret(assert(voicing.parse(text, name))), name)
      end
    end)

    it("frames a high voicing from the fret it starts on", function()
      for name, framing in pairs({
        ["Bb"] = { text = "x68876", base = 6 },
        ["Bm"] = { text = "x79987", base = 7 },
        ["C#m"] = { text = "9-11-11-9-9-9", base = 9 },
        ["E at the twelfth"] = { text = "12-14-14-13-12-12", base = 12 },
      }) do
        local v = assert(voicing.parse(framing.text, name))
        assert.are.equal(framing.base, voicing.baseFret(v), name)
      end
    end)

    it("still frames from the lowest fretted fret when a string rings open", function()
      -- An open A under a shape at the seventh fret. The nut cannot be shown
      -- without putting the fretted notes outside a five-fret window, so the
      -- window wins and the open string keeps its ring above the diagram —
      -- which is how songbooks notate it.
      assert.are.equal(7, voicing.baseFret(assert(voicing.parse("x-0-9-9-7-x"))))
    end)
  end)

  describe("choosing a framing by hand", function()
    it("refuses a window starting above the nut, which is not a place on a neck", function()
      -- The override control offers a number, and a number can be nudged below
      -- 1. There is no fret 0 to start a window at, and an open C would
      -- otherwise "fit" a window at fret 0 and draw its dots a cell too low.
      local C = assert(voicing.parse("x32010", "C"))
      assert.is_false(voicing.canFrame(C.frets, 0))
      assert.is_false(voicing.canFrame(C.frets, -3))
    end)

    it("reframes the diagram without moving a single finger", function()
      -- A Bm at the seventh derives a window at the seventh. A guitarist who
      -- thinks of it as a fifth-position shape gets to say so, and the shape
      -- they play does not change because they said it.
      local Bm = assert(voicing.parse("x79987", "Bm"))
      local reframed = voicing.setBaseFret(Bm, 5)
      assert.are.equal(5, voicing.baseFret(reframed))
      assert.are.same(Bm.frets, reframed.frets)
      assert.are.equal("x79987", voicing.toText(reframed))
    end)

    it("gives the framing back to the derivation when the override is cleared", function()
      -- Slice 004 drops an override that has stopped framing the shape, but
      -- there was no way to change one's mind about an override that still
      -- works. Clearing it is that way back: the chord returns to deriving its
      -- own framing, and reopening it later will not find a frozen window.
      local Bm = voicing.setBaseFret(assert(voicing.parse("x79987", "Bm")), 5)
      local derived = voicing.setBaseFret(Bm, nil)
      assert.is_nil(derived.baseFret)
      assert.are.equal(7, voicing.baseFret(derived))
    end)

    it("does not keep a window that cannot hold the shape, even dormant", function()
      -- An open C cannot be framed from the ninth: its dots would sit above the
      -- top of the diagram. Slice 004 already ignores such an override when it
      -- draws, but STORING one lets it lie dormant and come back to life the
      -- day the shape moves under it — a framing the user never chose,
      -- reappearing weeks later. It is refused at the point of setting.
      local C = assert(voicing.parse("x32010", "C"))
      local refused = voicing.setBaseFret(C, 9)
      assert.is_nil(refused.baseFret)
      assert.are.equal(1, voicing.baseFret(refused))
    end)
  end)

  describe("re-typing the text of a chord that already exists", function()
    it("keeps a barre, which the text form cannot express", function()
      local existing = voicing.new({
        frets = { 1, 3, 3, 2, 1, 1 },
        name = "F",
        barres = { { fret = 1, from = 1, to = 6 } },
      })
      local edited = assert(voicing.parse("133215", "F", existing))
      assert.are.equal("133215", voicing.toText(edited))
      assert.are.same(existing.barres, edited.barres)
    end)

    it("keeps a base fret the user overrode", function()
      local existing = voicing.new({ frets = { -1, 7, 9, 9, 8, 7 }, baseFret = 5 })
      assert.are.equal(5, voicing.baseFret(assert(voicing.parse("x79987", "Bm", existing))))
    end)

    it("keeps the override when one string of the shape moves inside the window", function()
      local existing = voicing.new({ frets = { -1, 7, 9, 9, 8, 7 }, baseFret = 5 })
      assert.are.equal(5, voicing.baseFret(assert(voicing.parse("x79986", "Bm", existing))))
    end)

    it("drops an override the new shape has moved out from under", function()
      -- Retyping a completely different chord must not keep a window that
      -- cannot show it: framed from the fifth fret, an open C has its dots
      -- above the top of the diagram. The framing goes back to derived.
      local existing = voicing.new({ frets = { -1, 7, 9, 9, 8, 7 }, baseFret = 5 })
      local retyped = assert(voicing.parse("x32010", "C", existing))
      assert.is_nil(retyped.baseFret)
      assert.are.equal(1, voicing.baseFret(retyped))
    end)

    it("preserves everything the text form cannot say", function()
      -- THE GUARD SLICE 008 DEPENDS ON. The text field is re-parsed on every
      -- keystroke, and a chord string can say only where the fingers are: it
      -- has no way to write a barre, a finger number, or a framing the user
      -- chose. If parsing REPLACED the voicing instead of merging into it,
      -- nudging one string would silently delete all three — and the barre is
      -- the one the user would notice a week later, in a diagram they trusted.
      local existing = voicing.new({
        frets = { 5, 7, 7, 6, 5, 5 },
        fingers = { 1, 3, 4, 2, 1, 1 },
        barres = { { fret = 5, from = 1, to = 6 } },
        baseFret = 4,
        name = "A",
      })
      local edited = assert(voicing.parse("577655", nil, existing))

      assert.are.same({ 5, 7, 7, 6, 5, 5 }, edited.frets)
      assert.are.same(existing.barres, edited.barres)
      assert.are.same(existing.fingers, edited.fingers)
      assert.are.equal(4, voicing.baseFret(edited))
      assert.are.equal("A", edited.name)
    end)

    it("never damages the chord being edited, at any keystroke of the edit", function()
      -- What the text field actually does: re-parse on every keystroke against
      -- the voicing being edited. Every intermediate state of that has to
      -- either answer with a voicing that still carries the barre, or refuse —
      -- and it must never alter the chord it was handed, because a refusal
      -- leaves the UI showing exactly that chord.
      local F = voicing.new({
        frets = { 1, 3, 3, 2, 1, 1 },
        barres = { { fret = 1, from = 1, to = 6 } },
        name = "F",
      })
      for n = 1, #"133215" do
        local edited = voicing.parse(("133215"):sub(1, n), nil, F)
        if edited then
          assert.are.same(F.barres, edited.barres)
          assert.are.equal("F", edited.name)
        end
        assert.are.same({ 1, 3, 3, 2, 1, 1 }, F.frets)
        assert.are.same({ { fret = 1, from = 1, to = 6 } }, F.barres)
      end
    end)

    it("takes the new name, so a rename is not a shape change", function()
      local existing = voicing.new({ frets = { -1, 3, 2, 0, 1, 0 }, name = "C" })
      assert.are.equal("Cadd9", assert(voicing.parse("x32010", "Cadd9", existing)).name)
    end)

    it("gives a renamed chord a new image, because the name is drawn on it", function()
      local existing = voicing.new({
        frets = { 1, 3, 3, 2, 1, 1 },
        name = "F",
        barres = { { fret = 1, from = 1, to = 6 } },
      })
      local renamed = assert(voicing.parse(voicing.toText(existing), "F major", existing))
      assert.are.same(existing.frets, renamed.frets)
      assert.are.same(existing.barres, renamed.barres)
      assert.are_not.equal(voicing.fingerprint(existing), voicing.fingerprint(renamed))
    end)
  end)

  describe("editing one string", function()
    it("moves that string and leaves the others where they were", function()
      local C = assert(voicing.parse("x32010", "C"))
      assert.are.equal("x32013", voicing.toText(voicing.setFret(C, 6, 3)))
    end)

    it("leaves the chord it was given untouched, so backing out restores nothing", function()
      local C = assert(voicing.parse("x32010", "C"))
      voicing.setFret(C, 6, 3)
      assert.are.equal("x32010", voicing.toText(C))
    end)

    it("keeps the barre and the name, which one string's position does not touch", function()
      local F = voicing.new({
        frets = { 1, 3, 3, 2, 1, 1 },
        name = "F",
        barres = { { fret = 1, from = 1, to = 6 } },
      })
      local edited = voicing.setFret(F, 3, 5)
      assert.are.equal("F", edited.name)
      assert.are.same(F.barres, edited.barres)
    end)
  end)

  describe("naming a chord", function()
    it("renames without rebuilding it, and asks for a new image", function()
      -- The name field cannot be routed through `parse`: a name is typed while
      -- the chord string next to it may be half-finished, and a rename must not
      -- depend on the text field being parseable at that instant.
      local F = voicing.new({
        frets = { 1, 3, 3, 2, 1, 1 },
        barres = { { fret = 1, from = 1, to = 6 } },
        name = "F",
      })
      local renamed = voicing.setName(F, "F major")

      assert.are.equal("F major", renamed.name)
      assert.are.same(F.frets, renamed.frets)
      assert.are.same(F.barres, renamed.barres)
      -- The name is drawn on the diagram, so it is part of the fingerprint: a
      -- rename has to produce a different file rather than leave REAPER showing
      -- the picture with the old title on it.
      assert.are_not.equal(voicing.fingerprint(F), voicing.fingerprint(renamed))
      assert.are.equal("F", F.name)
    end)
  end)

  describe("clicking a cell of the grid", function()
    it("places a dot where there was none", function()
      local blank = voicing.new()
      assert.are.equal("xxx2xx", voicing.toText(voicing.toggleFret(blank, 4, 2)))
    end)

    it("clears the dot when the same cell is clicked again, back to muted", function()
      -- Muted, not open. Deleting a dot must not claim the string is sounded:
      -- the ring above the nut says that, and only a click up there means it.
      local placed = voicing.toggleFret(voicing.new(), 4, 2)
      assert.are.equal("xxxxxx", voicing.toText(voicing.toggleFret(placed, 4, 2)))
    end)

    it("rings a muted string open when the row above the nut is clicked", function()
      local blank = voicing.new()
      local rung = voicing.toggleFret(blank, 1, voicing.MUTED)
      assert.are.equal(voicing.OPEN, rung.frets[1])
    end)

    it("mutes an open string when the row above the nut is clicked", function()
      local C = assert(voicing.parse("x32010", "C"))
      assert.are.equal("x3201x", voicing.toText(voicing.toggleFret(C, 6, voicing.OPEN)))
    end)

    it("lifts the finger off a fretted string clicked above the nut", function()
      -- The row above the nut says what a string does when nothing frets it, so
      -- clicking it is a claim about the string, not about the dot below.
      local C = assert(voicing.parse("x32010", "C"))
      assert.are.equal("x32000", voicing.toText(voicing.toggleFret(C, 5, voicing.OPEN)))
    end)
  end)

  describe("storing a voicing", function()
    it("decodes back to the shape it was encoded from", function()
      local v = assert(voicing.parse("x32010", "C"))
      local back = assert(voicing.decode(voicing.encode(v)))
      assert.are.same(v.frets, back.frets)
    end)

    it("writes one token with nothing a state chunk line could mangle", function()
      local encoded = voicing.encode(voicing.new({ name = "C \"add9\"\n'x'\t100% `sure` <>" }))
      assert.are.equal(encoded, encoded:match("^[^%s\"'`<>]+$"))
    end)

    it("keeps a name containing spaces, quotes, commas and percent signs", function()
      local name = [[C "add9", 100% sure; bar`d]]
      local back = assert(voicing.decode(voicing.encode(voicing.new({ name = name }))))
      assert.are.equal(name, back.name)
    end)

    it("keeps barres, which nothing draws yet", function()
      local barres = { { fret = 1, from = 1, to = 6 }, { fret = 3, from = 2, to = 4 } }
      local v = voicing.new({ frets = { 1, 3, 3, 2, 1, 1 }, name = "F", barres = barres })
      assert.are.same(barres, assert(voicing.decode(voicing.encode(v))).barres)
    end)

    it("keeps a base fret the user overrode", function()
      -- Framed from the fifth rather than the seventh, which is where the
      -- derivation would have put it: a choice only the user could have made.
      local v = voicing.new({ frets = { -1, 7, 9, 9, 8, 7 }, name = "Bm", baseFret = 5 })
      local back = assert(voicing.decode(voicing.encode(v)))
      assert.are.equal(5, back.baseFret)
      assert.are.equal(5, voicing.baseFret(back))
    end)

    it("ignores a stored override that no longer frames the chord it was saved with", function()
      -- Belt and braces for data written before the rule existed, or by hand.
      local damaged = voicing.encode(voicing.new({ frets = { -1, 3, 2, 0, 1, 0 }, baseFret = 9 }))
      assert.are.equal(1, voicing.baseFret(assert(voicing.decode(damaged))))
    end)

    it("keeps finger numbers, which nothing renders yet", function()
      local fingers = { [2] = 3, [3] = 2, [5] = 1 }
      local v = voicing.new({ frets = { -1, 3, 2, 0, 1, 0 }, fingers = fingers, name = "C" })
      assert.are.same(fingers, assert(voicing.decode(voicing.encode(v))).fingers)
    end)

    it("refuses a chord stored in a format it does not know, rather than misreading it", function()
      local stored = voicing.encode(assert(voicing.parse("x32010", "C")))
      local v, err = voicing.decode((stored:gsub("^v1", "v9")))
      assert.is_nil(v)
      assert.is_truthy(err:find("v9", 1, true))
    end)

    it("refuses a truncated chord rather than padding it with muted strings", function()
      local v, err = voicing.decode("v1;s=6;f=-1,3,2;g=;b=;p=;n=C")
      assert.is_nil(v)
      assert.is_string(err)
    end)
  end)

  describe("fingerprinting", function()
    it("gives the same fingerprint to the same voicing", function()
      assert.are.equal(
        voicing.fingerprint(assert(voicing.parse("x32010", "C"))),
        voicing.fingerprint(assert(voicing.parse("x32010", "C"))))
    end)

    it("changes when a single fret changes", function()
      assert.are_not.equal(
        voicing.fingerprint(assert(voicing.parse("x32010", "C"))),
        voicing.fingerprint(assert(voicing.parse("x32013", "C"))))
    end)

    it("changes when the name changes, because the name is drawn on the diagram", function()
      assert.are_not.equal(
        voicing.fingerprint(assert(voicing.parse("x32010", "C"))),
        voicing.fingerprint(assert(voicing.parse("x32010", "Cmaj"))))
    end)

    it("changes when a barre is added", function()
      local plain = assert(voicing.parse("133211", "F"))
      local barred = voicing.new({ frets = plain.frets, name = "F",
        barres = { { fret = 1, from = 1, to = 6 } } })
      assert.are_not.equal(voicing.fingerprint(plain), voicing.fingerprint(barred))
    end)

    it("is lowercase and free of separators, so it is safe as a filename", function()
      local fp = voicing.fingerprint(assert(voicing.parse("x32010", "C/G #1")))
      assert.are.equal(fp, fp:lower())
      assert.are.equal(fp, fp:match("^[%w]+$"))
    end)
  end)
end)
