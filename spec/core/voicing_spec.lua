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
