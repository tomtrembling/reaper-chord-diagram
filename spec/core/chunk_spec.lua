local chunk = require("core.chunk")
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

    it("carries through a line it does not recognise", function()
      -- The voicing now lives in the item's EXTENDED STATE, and REAPER
      -- serialises that into this same chunk in a form nothing here has seen
      -- documented. An image write must therefore remove the three fields it
      -- owns and nothing else, or editing a chord's picture eats the chord.
      --
      -- `XYZZY` is a deliberate stand-in, not a guess at REAPER's spelling: what
      -- is pinned here is the "and nothing else", which holds whatever the real
      -- line turns out to look like.
      local carrying = fixtures.EMPTY_ITEM:gsub("\nCHANMODE 0\n", "\nCHANMODE 0\nXYZZY 42\n")
      local out = assert(chunk.setImage(carrying,
        { filename = "a.png", flags = 3, notes = "C" }))
      local added = "\n<NOTES\n|C\n>\nRESOURCEFN \"a.png\"\nIMGRESOURCEFLAGS 3"
      assert.are.equal(carrying, (out:gsub(added:gsub("%p", "%%%0"), "")))
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
