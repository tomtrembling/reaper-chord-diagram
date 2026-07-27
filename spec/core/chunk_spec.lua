local chunk = require("core.chunk")
local voicing = require("core.voicing")
local fixtures = require("fixtures.item_chunks")

describe("chunk", function()
  describe("attaching an image to an item with no notes", function()
    it("writes the image filename and the display flags", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM, {
        filename = "chord-diagrams/8fbb1c2d9a4e7051.png",
        flags = 3,
        notes = "Cadd9",
      }))
      assert.is_truthy(out:find('\nRESOURCEFN "chord%-diagrams/8fbb1c2d9a4e7051%.png"\n'))
      assert.is_truthy(out:find("\nIMGRESOURCEFLAGS 3\n"))
    end)

    it("writes a non-empty notes block, without which the flags are ignored", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "Cadd9" }))
      assert.is_truthy(out:find("\n<NOTES\n|Cadd9\n>\n"))
    end)

    it("refuses to write an image with no notes", function()
      local out, err = chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "" })
      assert.is_nil(out)
      assert.is_string(err)
    end)

    it("puts the fields inside the item, before its closing angle bracket", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "Cadd9" }))
      assert.is_truthy(out:find("\nIMGRESOURCEFLAGS 3\n>%s*$"))
    end)

    it("leaves every other line of the chunk exactly as it found it", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "Cadd9" }))
      local added = "\n<NOTES\n|Cadd9\n>\nRESOURCEFN \"a.png\"\nIMGRESOURCEFLAGS 3"
      assert.are.equal(fixtures.EMPTY_ITEM, (out:gsub(added:gsub("%p", "%%%0"), "")))
    end)

    it("keeps nested sub-chunks intact", function()
      local out = assert(chunk.setImage(fixtures.AUDIO_ITEM,
        { filename = "a.png", flags = 3, notes = "Cadd9" }))
      assert.is_truthy(out:find('<SOURCE WAVE\nFILE "audio/guitar%-di%-01%.wav"\n>'))
      assert.are.equal(1, select(2, out:gsub("IMGRESOURCEFLAGS", "")))
    end)
  end)

  describe("replacing the image on an item that already carries a chord", function()
    it("does not leave a second copy of the fields behind", function()
      local out = assert(chunk.setImage(fixtures.ITEM_WITH_CHORD,
        { filename = "chord-diagrams/new.png", flags = 3, notes = "C" }))
      assert.are.equal(1, select(2, out:gsub("RESOURCEFN", "")))
      assert.are.equal(1, select(2, out:gsub("IMGRESOURCEFLAGS", "")))
      assert.are.equal(1, select(2, out:gsub("<NOTES", "")))
      assert.is_falsy(out:find("3a8f57a773ffd3a0"))
    end)

    it("keeps the item's own fields untouched while doing so", function()
      local out = assert(chunk.setImage(fixtures.ITEM_WITH_CHORD,
        { filename = "chord-diagrams/new.png", flags = 3, notes = "C" }))
      assert.is_truthy(out:find("\nPOSITION 8%.5\n"))
      assert.is_truthy(out:find("\nGUID {2F9A6B14%-7C05%-48D3%-B1E6%-3A8C4D9E0F52}\n"))
    end)
  end)

  describe("storing the voicing on the item", function()
    it("reads back the voicing that was written", function()
      local v = assert(voicing.parse("x32010", "C add9"))
      local out = assert(chunk.setVoicing(fixtures.EMPTY_ITEM, v))
      assert.are.same(v, assert(chunk.readVoicing(out)))
    end)

    it("reads the voicing off an item that already carries a chord", function()
      local v = assert(chunk.readVoicing(fixtures.ITEM_WITH_CHORD))
      assert.are.equal("x32010", voicing.toText(v))
      assert.are.equal("Cadd9", v.name)
    end)

    it("reads nothing back from an item that has never carried a chord", function()
      assert.is_nil(chunk.readVoicing(fixtures.EMPTY_ITEM))
    end)

    it("replaces the stored voicing rather than stacking a second one", function()
      local out = assert(chunk.setVoicing(fixtures.ITEM_WITH_CHORD,
        assert(voicing.parse("133211", "F"))))
      assert.are.equal(1, select(2, out:gsub("CHORDDIAGRAM", "")))
      assert.are.equal("133211", voicing.toText(assert(chunk.readVoicing(out))))
    end)

    it("leaves every other line of the chunk exactly as it found it", function()
      local v = assert(voicing.parse("x32010", "C"))
      local out = assert(chunk.setVoicing(fixtures.EMPTY_ITEM, v))
      local added = "\nCHORDDIAGRAM " .. voicing.encode(v)
      assert.are.equal(fixtures.EMPTY_ITEM, (out:gsub(added:gsub("%p", "%%%0"), "")))
    end)

    it("keeps the image the item is already showing", function()
      local out = assert(chunk.setVoicing(fixtures.ITEM_WITH_CHORD,
        assert(voicing.parse("133211", "F"))))
      assert.is_truthy(out:find('\nRESOURCEFN "chord%-diagrams/3a8f57a773ffd3a0%.png"\n'))
      assert.is_truthy(out:find("\nIMGRESOURCEFLAGS 3\n"))
    end)

    it("survives replacing the image, so an edit keeps the data that produced it", function()
      local out = assert(chunk.setImage(fixtures.ITEM_WITH_CHORD,
        { filename = "chord-diagrams/new.png", flags = 3, notes = "Cadd9" }))
      assert.are.equal("x32010", voicing.toText(assert(chunk.readVoicing(out))))
    end)
  end)

  describe("text that Lua patterns would otherwise mangle", function()
    it("stores a note containing a percent sign literally", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "C 100% sure" }))
      assert.is_truthy(out:find("\n|C 100%% sure\n", 1, false))
    end)

    it("prefixes every line of a multi-line note, whatever the line endings", function()
      local out = assert(chunk.setImage(fixtures.EMPTY_ITEM,
        { filename = "a.png", flags = 3, notes = "C\r\nadd9" }))
      assert.is_truthy(out:find("\n<NOTES\n|C\n|add9\n>\n", 1, true))
    end)
  end)
end)
