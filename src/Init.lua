--- Divvy's History for Balatro - Init.lua
--
-- Global values that must be present for the rest of this mod to work.

if not DV then DV = {} end

DV.HIST = {
   -- TODO: Move key data into `G.GAME.DV`?
   history = {},
   view = {
      abs_round = 1,
      text = {" ", " ", " ", " "},
   },
   latest = {
     rel_round = 0,
     abs_round = 0,
     ante = 0,
   },
   RECORD_TYPE = {
      SKIP = 0,
      HAND = 1,
      DISCARD = 2,
      SHOP = 3,
   },
   STORAGE_TYPE = {
      AUTO = "auto",
      MANUAL = "save",
      WIN = "win",
      LOSS = "loss",
   },
   PATHS = {
      STORAGE = "DVHistory",
      AUTOSAVES = "_autosaves",
   },
}

DV.HIST._start_up = Game.start_up
function Game:start_up()
   DV.HIST._start_up(self)

   -- Initialize settings framework (from DVSettings)
   if not G.SETTINGS.DV then G.SETTINGS.DV = {} end
   if not G.DV then G.DV = {} end
   if not G.DV.options then G.DV.options = {} end

   if not G.SETTINGS.DV.HIST then
      G.SETTINGS.DV.HIST = true
      G.SETTINGS.DV.autosave = true
      G.SETTINGS.DV.autosaves_per_run = 5
      G.SETTINGS.DV.autosaves_total = 10
   end

   DV.settings = true
   G.DV.options["Autosaves"] = "get_history_settings_page"

   -- Settings UI callback (from DVSettings)
   function G.FUNCS.dv_settings_change(args)
      if not args or not args.cycle_config then return end
      local callback_args = args.cycle_config.opt_args
      local page_object = callback_args.ui
      local page_wrap = page_object.parent
      local new_option_idx = args.to_key
      local new_option_def = callback_args.indexed_options[new_option_idx]
      page_wrap.config.object:remove()
      page_wrap.config.object = UIBox({
         definition = DV[G.DV.options[new_option_def]](),
         config = { parent = page_wrap, type = "cm" }
      })
      page_wrap.UIBox:recalculate()
   end
end

-- Settings Tab Logic (from DVSettings)
function DV.create_settings_tab(num_tabs)
   if num_tabs > 4 then return nil end
   return {
      label = "Other",
      tab_definition_function = DV.get_settings_tab,
   }
end

function DV.get_settings_tab()
   local options = {}
   local first_option_def = nil
   for option_name, option_def in pairs(G.DV.options) do
      if #options == 0 then first_option_def = option_def end
      table.insert(options, option_name)
   end
   local first_page = UIBox({
         definition = DV[first_option_def](),
         config = {type = "cm"}
   })
   if #options == 1 then
      return
         {n=G.UIT.ROOT, config={align="cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR}, nodes={
             {n=G.UIT.O, config={object = first_page}}
         }}
   end
   return
      {n=G.UIT.ROOT, config={align = "cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR}, nodes={
          {n=G.UIT.C, config={align = "cm"}, nodes={
              {n=G.UIT.R, config={align = "tm", minh = 5.5}, nodes={
                  {n=G.UIT.O, config={object = first_page}}
              }},
              {n=G.UIT.R, config={align = "bm"}, nodes={
                  create_option_cycle({
                        options = options,
                        current_option = 1,
                        opt_callback = "dv_settings_change",
                        opt_args = {ui = first_page, indexed_options = options},
                        w = 5, colour = G.C.RED, cycle_shoulders = false})
              }}
          }}
      }}
end


DV.HIST._start_run = Game.start_run
function Game:start_run(args)
   DV.HIST._start_run(self, args)

   if not args or not args.savetext then
      -- New run, so modify `GAME` table with custom storage:
      if not G.GAME.DV then G.GAME.DV = {} end
      G.GAME.DV.run_id = DV.HIST.simple_uuid()

      -- ...and reset mod data:
      DV.HIST.history = {}
      DV.HIST.latest = {
         rel_round = 0,
         abs_round = 0,
         ante = 0,
      }
   else
      -- Loaded run -- G.GAME.DV may be absent if the save predates DVHistory:
      if not G.GAME.DV then G.GAME.DV = {} end
      -- Generate a run_id if missing (needed by SaveManager to avoid a thread crash):
      if not G.GAME.DV.run_id then G.GAME.DV.run_id = DV.HIST.simple_uuid() end
      DV.HIST.history = G.GAME.DV.history or {}
      DV.HIST.latest = G.GAME.DV.latest or { rel_round = 0, abs_round = 0, ante = 0 }

      -- If history is empty the current blind slot was never recorded (select_blind already
      -- fired before this continue). Build a minimal slot from the live game state so that
      -- shop hooks (get_shop_entry) don't crash on history[ante][round] = nil:
      if DV.HIST.latest.ante == 0 then
         local ante      = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
         local states    = (G.GAME.round_resets and G.GAME.round_resets.blind_states) or {}
         local rel_round = (states["Small"] == "Current" and 1)
                        or (states["Big"]   == "Current" and 2)
                        or 3
         DV.HIST.latest.ante      = ante
         DV.HIST.latest.rel_round = rel_round
         DV.HIST.latest.abs_round = (ante - 1) * 3 + rel_round
         if not DV.HIST.history[ante] then DV.HIST.history[ante] = {} end
         if not DV.HIST.history[ante][rel_round] then DV.HIST.history[ante][rel_round] = {} end
      end
   end
end

DV.HIST._save_run = save_run
function save_run()
   if not G.GAME.DV then G.GAME.DV = {} end
   G.GAME.DV.history = DV.HIST.history
   G.GAME.DV.latest = DV.HIST.latest
   DV.HIST._save_run()
end
