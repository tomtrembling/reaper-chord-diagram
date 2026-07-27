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
  end)

  describe("framing", function()
    it("shows the nut for an open-position chord", function()
      assert.are.equal(1, voicing.baseFret(assert(voicing.parse("x32010"))))
    end)

    it("shows the nut for a low chord with no open strings", function()
      -- F barre shape at the first fret.
      assert.are.equal(1, voicing.baseFret(assert(voicing.parse("133211"))))
    end)

    it("starts the window at the lowest fretted fret for a high chord", function()
      assert.are.equal(7, voicing.baseFret(assert(voicing.parse("x79987"))))
    end)

    it("shows the nut for a chord with no fretted strings at all", function()
      assert.are.equal(1, voicing.baseFret(assert(voicing.parse("0x000x"))))
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
      local v = voicing.new({ frets = { -1, 3, 2, 0, 1, 0 }, name = "C", baseFret = 5 })
      assert.are.equal(5, voicing.baseFret(assert(voicing.decode(voicing.encode(v)))))
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
