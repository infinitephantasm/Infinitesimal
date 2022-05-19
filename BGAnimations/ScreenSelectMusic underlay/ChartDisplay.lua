local ItemW = 56
local ItemH = 56
local ItemAmount = ...
local ItemTotalW = ItemW * ((ItemAmount - 1) / 2)

local FrameX = -ItemTotalW

local PlayerChartIndex = { PlayerNumber_P1 = 1, PlayerNumber_P2 = 1 }
local PlayerCanMove = { PlayerNumber_P1 = true, PlayerNumber_P2 = true }

local ChartArray = nil
local SongIsChosen = false
local PreviewDelay = THEME:GetMetric("ScreenSelectMusic", "SampleMusicDelay")
local CenterList = LoadModule("Config.Load.lua")("CenterChartList", "Save/OutFoxPrefs.ini")

function SortCharts(a, b)
    if a:GetStepsType() == b:GetStepsType() then
        return a:GetMeter() < b:GetMeter()
    else
        return a:GetStepsType() > b:GetStepsType()
    end
end

local ChartLabels = {
	"NEW",
	"ANOTHER",
	"PRO",
	"TRAIN",
	"QUEST",
	"UCS",
	"HIDDEN",
	"INFINITY",
	"JUMP",
}

local function InputHandler(event)
    local pn = event.PlayerNumber
    if not pn then return end
    
    -- To avoid control from a player that has not joined, filter the inputs out
    if pn == PLAYER_1 and not GAMESTATE:IsPlayerEnabled(PLAYER_1) then return end
    if pn == PLAYER_2 and not GAMESTATE:IsPlayerEnabled(PLAYER_2) then return end
    
	if SongIsChosen and PlayerCanMove[pn] then
		-- Filter out everything but button presses
		if event.type == "InputEventType_Repeat" or event.type == "InputEventType_Release" then return end
		
		local button = event.button
		if button == "MenuLeft" or button == "DownLeft" then
            if PlayerChartIndex[pn] == 1 then return else
            PlayerChartIndex[pn] = PlayerChartIndex[pn] - 1 end
			MESSAGEMAN:Broadcast("CurrentChartChanged", { Player = pn })
		elseif button == "MenuRight" or button == "DownRight" then
            if PlayerChartIndex[pn] == #ChartArray then return else
            PlayerChartIndex[pn] = PlayerChartIndex[pn] + 1 end
			MESSAGEMAN:Broadcast("CurrentChartChanged", { Player = pn })
		end
	end
    return
end

local t = Def.ActorFrame {
	OnCommand=function(self) 
		SCREENMAN:GetTopScreen():AddInputCallback(InputHandler) 
		self:playcommand("Refresh")
	end,
    
    -- Prevent the chart list from moving when transitioning
    OffCommand=function(self)
        SongIsChosen = false
    end,
	
	-- Update chart list
	CurrentChartChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CurrentSongChangedMessageCommand=function(self) self:playcommand("Refresh") end,

	-- These are to control input and chart highlights appearing.
	SongChosenMessageCommand=function(self) SongIsChosen = true self:playcommand("Refresh") end,
	SongUnchosenMessageCommand=function(self) SongIsChosen = false self:playcommand("Refresh") end,
    OptionsListOpenedMessageCommand=function(self, params) PlayerCanMove[params.Player] = false end,
    OptionsListClosedMessageCommand=function(self, params) PlayerCanMove[params.Player] = true end,

	RefreshCommand=function(self)
		ChartArray = nil
		local CurrentSong = GAMESTATE:GetCurrentSong()
		if CurrentSong then 
			ChartArray = SongUtil.GetPlayableSteps(CurrentSong)
			table.sort(ChartArray, SortCharts)
		end

		if ChartArray then
			-- Correct player chart indexes to ensure they're not off limits
			if PlayerChartIndex[PLAYER_1] < 1 then PlayerChartIndex[PLAYER_1] = 1
            elseif PlayerChartIndex[PLAYER_1] > #ChartArray then PlayerChartIndex[PLAYER_1] = #ChartArray end
            
			if PlayerChartIndex[PLAYER_2] < 1 then PlayerChartIndex[PLAYER_2] = 1
            elseif PlayerChartIndex[PLAYER_2] > #ChartArray then PlayerChartIndex[PLAYER_2] = #ChartArray end
			
			-- Set the selected charts and broadcast a new message to avoid possible
			-- race conditions trying to obtain the currently selected chart.
			if GAMESTATE:IsPlayerEnabled(PLAYER_1) then 
				GAMESTATE:SetCurrentSteps(PLAYER_1, ChartArray[PlayerChartIndex[PLAYER_1]]) 
			end
			if GAMESTATE:IsPlayerEnabled(PLAYER_2) then 
				GAMESTATE:SetCurrentSteps(PLAYER_2, ChartArray[PlayerChartIndex[PLAYER_2]])
			end
			
			local ChartIndex = PlayerChartIndex[PLAYER_1] > PlayerChartIndex[PLAYER_2] and PlayerChartIndex[PLAYER_1] or PlayerChartIndex[PLAYER_2]

			local ListOffset = 0
			if ChartIndex + 1 > ItemAmount then
                ListOffset = ChartIndex - ItemAmount + (ChartIndex == #ChartArray and 0 or 1)
			end

			if CenterList then
				-- Shift the positioning of the charts if they don't take up all visible slots
				local ChartArrayW = ItemW * ((#ChartArray < ItemAmount and #ChartArray or ItemAmount) - 1) / 2
				self:x(ItemTotalW - ChartArrayW)
			end

			if #ChartArray > ItemAmount then
				self:GetChild("")[ItemAmount+1]:GetChild("MoreLeft"):visible(ChartIndex + 1 > ItemAmount)
				self:GetChild("")[ItemAmount+1]:GetChild("MoreRight"):visible(ChartIndex + 1 < #ChartArray)
			else
				self:GetChild("")[ItemAmount+1]:GetChild("MoreLeft"):visible(false)
				self:GetChild("")[ItemAmount+1]:GetChild("MoreRight"):visible(false)
			end

			for i=1,ItemAmount do
				local Chart = ChartArray[ i + ListOffset ]

				if Chart then
					local ChartMeter = Chart:GetMeter()
					if ChartMeter == 99 then ChartMeter = "??" end
					local ChartDescription = Chart:GetDescription()

					self:GetChild("")[i]:GetChild("Icon"):visible(true):diffuse(ChartTypeToColor(Chart))
                    self:GetChild("")[i]:GetChild("IconTrim"):visible(true)
					self:GetChild("")[i]:GetChild("Level"):visible(true):settext(ChartMeter)
					self:GetChild("")[i]:GetChild("HighlightP1"):visible(
                        (PlayerChartIndex[PLAYER_1] == i + ListOffset) and SongIsChosen and GAMESTATE:IsHumanPlayer(PLAYER_1))
                    self:GetChild("")[i]:GetChild("HighlightP2"):visible(
                        (PlayerChartIndex[PLAYER_2] == i + ListOffset) and SongIsChosen and GAMESTATE:IsHumanPlayer(PLAYER_2))

                    --local ChartLabelString = ""
                    local ChartLabelIndex = 0

                    for Index, String in pairs(ChartLabels) do
						if string.find(ToUpper(Chart:GetDescription()), String) then
							--ChartLabelString = String
                            ChartLabelIndex = Index
						end
					end

                    if ChartLabelIndex ~= 0 then
                        self:GetChild("")[i]:GetChild("Label"):visible(true):setstate(ChartLabelIndex - 1)
                    else
                        self:GetChild("")[i]:GetChild("Label"):visible(false)
                    end
				else
                    if not CenterList then
                        self:GetChild("")[i]:GetChild("Icon"):visible(true):diffuse(Color.White):diffusealpha(0.25)
                        self:GetChild("")[i]:GetChild("IconTrim"):visible(true)
                    else
                        self:GetChild("")[i]:GetChild("Icon"):visible(false)
                        self:GetChild("")[i]:GetChild("IconTrim"):visible(false)
                    end
					self:GetChild("")[i]:GetChild("Level"):visible(false)
                    self:GetChild("")[i]:GetChild("Label"):visible(false)
					self:GetChild("")[i]:GetChild("HighlightP1"):visible(false)
                    self:GetChild("")[i]:GetChild("HighlightP2"):visible(false)
				end
			end
		else
			for i=1,ItemAmount do
				self:GetChild("")[i]:GetChild("Icon"):visible(false)
                self:GetChild("")[i]:GetChild("IconTrim"):visible(false)
				self:GetChild("")[i]:GetChild("Level"):visible(false)
                self:GetChild("")[i]:GetChild("Label"):visible(false)
				self:GetChild("")[i]:GetChild("HighlightP1"):visible(false)
                self:GetChild("")[i]:GetChild("HighlightP2"):visible(false)
			end
		end
	end,
}

for i=1,ItemAmount do
	t[#t+1] = Def.ActorFrame {
		Def.Sprite {
			Name="Icon",
			Texture=THEME:GetPathG("", "DifficultyDisplay/Ball"),
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), 0)
			end
		},

        Def.Sprite {
			Name="IconTrim",
			Texture=THEME:GetPathG("", "DifficultyDisplay/Trim"),
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), 0)
			end
		},

		Def.BitmapText {
			Font="Montserrat numbers 40px",
			Name="Level",
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), 0):zoom(0.6):maxwidth(75)
			end
		},

        Def.Sprite {
			Name="Label",
            Texture=THEME:GetPathG("", "DifficultyDisplay/Labels"),
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), 16):animate(false)
			end
		},

        Def.Sprite {
			Name="HighlightP1",
			Texture=THEME:GetPathG("", "DifficultyDisplay/Cursor/P1"),
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), -22)
				:zoom(0.5)
				:bounce():effectmagnitude(0, -5, 0):effectclock("bgm")
				:visible(false)
			end
		},

        Def.Sprite {
			Name="HighlightP2",
			Texture=THEME:GetPathG("", "DifficultyDisplay/Cursor/P2"),
			InitCommand=function(self)
				self:xy(FrameX + ItemW * (i - 1), 22)
				:zoom(0.5)
				:bounce():effectmagnitude(0, 5, 0):effectclock("bgm")
				:visible(false)
			end
		},

		LoadActor(THEME:GetPathS("Common","value")) .. {}
	}
end

t[#t+1] = Def.ActorFrame {
    Def.Sprite {
        Name="MoreLeft",
        Texture=THEME:GetPathG("", "DifficultyDisplay/MoreLeft"),
        InitCommand=function(self)
            self:xy(FrameX - 16 - ItemW, 0):zoom(0.4):visible(false)
            :bounce():effectmagnitude(16, 0, 0):effectclock("bgm")
        end
    },
    Def.Sprite {
        Name="MoreRight",
        Texture=THEME:GetPathG("", "DifficultyDisplay/MoreRight"),
        InitCommand=function(self)
            self:xy(FrameX + 16 + ItemW * 12, 0):zoom(0.4):visible(false)
            :bounce():effectmagnitude(-16, 0, 0):effectclock("bgm")
        end
    },
	Def.Sound {
		File=THEME:GetPathS("Common", "value"),
		IsAction=true,
		CurrentChartChangedMessageCommand=function(self) self:play() end
	}
}

return t;
