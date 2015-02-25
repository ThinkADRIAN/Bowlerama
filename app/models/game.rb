class Game < ActiveRecord::Base
	has_many :frames, -> { order "frame_number asc" }, :dependent => :destroy
	accepts_nested_attributes_for :frames

	after_create :init

  def init
  	i = 1
    10.times { 
    	frame = Frame.new
    	frame.frame_number = i
    	frame.frame_score = 0
    	frame.save
    	self.frames << frame
    	i += 1
    }

    self.save
  end

	def rollBall
		self.resetPinsIfNecessary!

    # Handle first stroke for all frames
    if self.frame_stroke == 1 && self.current_frame <= 10
      self.bowled_pins = randomizePinCount( 0, 10 )
      self.pins_left = 10 - self.bowled_pins
    
    # Handle second stroke for frames 1 through 9
    elsif self.frame_stroke == 2 && self.current_frame < 10
      self.bowled_pins = randomizePinCount( 0, self.pins_left )
      self.pins_left = self.pins_left - self.bowled_pins

    # Handle second stroke for frame 10
    elsif self.frame_stroke == 2 && self.current_frame == 10
      if isLastStrokeStrike?
      	self.bowled_pins = randomizePinCount( 0, 10 )
        self.pins_left = 10 - self.bowled_pins
      else
        self.bowled_pins = randomizePinCount( 0, self.pins_left )
        self.pins_left = self.pins_left - self.bowled_pins
      end

  	# Handle third stroke for frame 10
	  elsif self.frame_stroke == 3 && self.current_frame == 10
      if isLastStrokeStrike? || isLastStrokeSpare?
      	self.bowled_pins = randomizePinCount( 0, 10 )
        self.pins_left = 10 - self.bowled_pins
      else
        self.bowled_pins = randomizePinCount( 0, self.pins_left )
        self.pins_left = self.pins_left - self.bowled_pins
      end
    end
	end

	def incrementFrameCount!
     self.current_frame += 1
  end

  def resetPinsIfNecessary!
    if ( self.frame_stroke == 1 && self.current_frame <= 10 ) || isLastStrokeStrike? || isLastStrokeSpare?
      @pins_left = 10
      @bowled_pins = 0
    end
  end

  def randomizePinCount( start_value, finish_value )
    return rand( start_value..finish_value )
  end

  def advanceFrameStroke!
    if self.frame_stroke == 1
      self.frame_stroke = 2
    elsif self.frame_stroke == 2 && self.current_frame == 10 
    	self.frame_stroke = 3
    elsif self.frame_stroke == 2 && self.current_frame < 10
      self.frame_stroke = 1
    end
  end

  def endGame
    self.frame_stroke = -1
  end

  def markScorecard!
    # Handle Strikes and Spares for frames 1 through 9
    if self.current_frame < 10 && self.pins_left == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
      end
      self.frame_stroke = 1
      incrementFrameCount!

    # Handle Strikes and Spares for frame 10
    elsif self.current_frame == 10 && @pins_left == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
        advanceFrameStroke
      elsif self.frame_stroke == 2
        if isLastStrokeStrike?
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
        end
        advanceFrameStroke
      elsif self.frame_stroke == 3
        if isLastStrokeStrike? || isLastStrokeSpare?
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "/")
        end
        endGame
      end

    # Handle Zero pins bowled in frame 10
    elsif self.current_frame == 10 && self.bowled_pins == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "-")
        advanceFrameStroke!
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "-")
        if isLastStrokeStrike?
        	advanceFrameStroke!
        else
        	endGame
        end
      elsif self.frame_stroke == 3
        self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "-")
        endGame
      end
    
    # Handle Zero pins bowled in frames 1 through 9
    elsif self.current_frame < 10 && self.bowled_pins == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "-")
        advanceFrameStroke!
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "-")
        advanceFrameStroke!
        incrementFrameCount!
      elsif self.frame_stroke == 3
        self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "-")
        endGame
      end

    # Handle all other strokes
    else
      if self.current_frame < 10 && self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: self.bowled_pins)
        advanceFrameStroke!
      elsif self.current_frame == 10 && self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: self.bowled_pins)
        advanceFrameStroke!
      elsif self.current_frame < 10 && self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: self.bowled_pins)
        advanceFrameStroke!
        incrementFrameCount!
      elsif self.current_frame == 10 && self.frame_stroke == 2
      	self.frames.where(frame_number: self.current_frame).update_all(second_stroke: self.bowled_pins)
    		if isLastStrokeStrike?
    			advanceFrameStroke!
    		else
    			endGame
    		end
    	elsif self.current_frame == 10 && self.frame_stroke == 3
      	self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: self.bowled_pins)
    		endGame
      end
    end
    calculateTotalScore!
  end

  def isLastStrokeStrike?
  	if self.frame_stroke == 2 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.first_stroke == "X"
  			return true
  		else
  			return false
  		end
  	elsif self.frame_stroke == 3 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.second_stroke == "X"
  			return true
  		else
  			return false
  		end
  	elsif self.frame_stroke == 1
  		frame = self.getFrame(self.current_frame-1)
  		if frame.first_stroke == "X"
  			return true
  		else
  			return false
  		end
  	end
  end

  def isLastStrokeSpare?
    if self.frame_stroke == 3 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.second_stroke == "/"
  			return true
  		else
  			return false
  		end
  	elsif self.frame_stroke == 1
  		frame = self.getFrame(self.current_frame-1)
  		if frame.second_stroke == "/"
  			return true
  		else
  			return false
  		end
  	end
  end

  def isStrike?(frame_to_check)
    self.frames.where(frame_number: frame_to_check, first_stroke: "X") ||
    self.frames.where(frame_number: frame_to_check, second_stroke: "X") ||
    self.frames.where(frame_number: frame_to_check, extra_stroke: "X")
  end

  def isSpare?(frame_to_check)
    self.frames.where(frame_number: frame_to_check, second_stroke: "/") || 
    self.frames.where(frame_number: frame_to_check, extra_stroke: "/")
  end

  def calculateTotalScore!
  	if self.current_frame == 1 || (self.current_frame > 1 && self.frame_stroke > 1) || self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  	elsif self.frame_stroke == 1 || (self.current_frame >= 2 && self.frame_stroke == 1)
  		frame = self.getFrame(self.current_frame-1)
  	end
  	frame.setScore!(self.bowled_pins)
    # Calculate the sum of values in @frame_scores
    self.total_score = 0
    self.frames.each { |frame| self.total_score += frame.frame_score unless frame.frame_score.nil? }
    self.total_score
  end

  def isGameOver?
    self.frame_stroke == -1
  end

  def getFrame(frame_number)
  	self.frames.each { |frame| 
  		if frame.frame_number == frame_number
  			return frame
  		end
  	}
  end

  def clearFrames!
    self.frames.clear
    self.init
    self.current_frame = 1
    self.frame_stroke = 1
    self.total_score = 0
    self.save
  end
end
