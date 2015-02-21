Pseudo-Code

Games has_many Players
Player has_many Frames
Players belongs_to Game
Frames belongs_to Player

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

	markScorecard() {
		if @frame_stroke == 1
			@first_strokes.push(@pins_left)
		elsif @frame_stroke == 2
			@second_strokes.push(@pins_left)
		else
			@extra_stroke == @pins_left			
		end
	}

	printThrowScore() {
		# Handle Strikes
		if @frame_stroke == 1 && @pins_left == 0
			if @current_frame < 10 
				return "X"
			end
		elsif @frame_stroke != 1 @pins_left == 0
			if current_frame == 10 && @scorecard.last == 0
				return "X"
			else
				return "/"
			end
		else
			throwScore = @pins_left
			return throwScore.to_s
		end
	}