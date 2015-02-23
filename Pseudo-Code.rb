Pseudo-Code

Current Feature:

	Calculate Frame Score

Upcoming Features:

	Calculate Total Score
	Reset Game Button
	Show Scorecard (Use Tables)

Current Challenge:

	Cannot Get Frame Score to Tally Correctly

Resolved:

	Bowl Button
	Bowl Action for Games Controller

----------

Player has_many Games
Game has_many Frames
Game belongs_to Player
Frames belongs_to Game

# Model
Player
	

Game
	current_frame integer
	frame_stroke integer
	total_score integer

Frame
	first_stroke string
	second_stroke string
	extra_stoke string
	frame_score integer
	frame_number integer

# Controller
	Game
		bowl
		reset

Player
	@first_strokes[0-9]
	@second_strokes[0-9]
	# Extra Stroke is only used if @second_strokes[9] is a Strike or Spare
	@extra_stroke

	@current_frame integer 1-10
	@frame_stroke integer 1-3
	@frame_scores[0-9]
	@total_score

	@bowled_pins integer 0-10
	@pins_left integer 0-10

	# Values for Strike and Spare
	STRIKE = 12
	SPARE = 11

	# Return randomized score
	bowl() {
		# Handle first stroke for all frames
		if @frame_stroke == 1 && @current_frame <= 10
			@bowled_pins = randomize_score (0..10)
			@pins_left = @bowled_pins - 10
		
		# Handle second stroke for frames 1 through 9
		elsif @frame_stroke == 2 && @current_frame < 10  
		  @pins_left = @bowled_pins - 10
		  @bowled_pins = @pins_left.randomize(0...pins_left)
		
		# Handle second and third stroke for frame 10  
		elsif @frame_stroke != 1 && @current_frame == 10
			if self.isLastTurnStrike()  || self.isLastTurnSpare()
				@bowled_pins = randomize_score (0..10)
			else
				@pins_left = @bowled_pins - 10
		  	@bowled_pins = @pins_left.randomize(0...pins_left)
	  	end
	  end

	  self.markScorecard	  
  	self.resetPins
	  return @bowled_pins
	}

	incrementFrameCount() {
		@current_frame += 1
	}

	advanceFrameStroke() {
		if @frame_stroke == 1
			@frame_stroke == 2
		else
			@frame_stroke == 1
		end
	}

	calculateFrameScore(frame_number) {
		
	}

	calculateTotalScore() {
		# Calculate the sum of values in @frame_scores

	}

	resetPins() {
		if (@frame_stroke == 2 && @current_frame < 10) || isLastTurnStrike || isLastTurnSpare
			@pins_left = 10
		end
	}

	isLastTurnSpare() {

	}

	isLastTurnStrike() {
			
	}

	markScorecard(frame_to_score) {
		# Handle Strikes and Spares for frames 1 through 9
		if @current_frame < 10 && @pins_left == 0
			if @frame_stroke == 1
				@first_strokes[frame_to_score - 1] = "X"
			elsif @frame_stroke == 2 
				@second_strokes[frame_to_score - 1] = "/"
			end
		
		# Handle Strikes and Spares for frame 10
		elsif current_frame == 10 && @pins_left == 0
			if @frame_stroke == 1 
				@first_strokes[frame_to_score - 1] = "X"
			elsif @frame_stroke == 2
				if isLastTurnStrike
					@second_strokes[frame_to_score - 1] = "X"
				else
					@second_strokes[frame_to_score - 1] = "X"
				end
			elsif @frame_stroke == 3
				if isLastTurnStrike || isLastTurnSpare
					@extra_stroke = "X"
				else
					@extra_stroke = "/"
				end
			end
		
		# Handle Zero pins bowled
		elsif @bowled_pins == 0
			if @frame_stroke == 1
				@first_strokes[frame_to_score - 1] = "-"
			elsif @frame_stroke == 2
				@second_strokes[frame_to_score - 1] = "-"
			elsif @frame_stroke == 3
				@extra_stroke = "-"
			end
		
		# Handle all other strokes
		else
			if @frame_stroke == 1 
				@first_strokes[frame_to_score - 1] = @bowled_pins
			elsif @frame_stroke == 2
				@second_strokes[frame_to_score - 1] = @bowled_pins
			else
				@extra_stroke = @bowled_pins.to_s
		end
	}