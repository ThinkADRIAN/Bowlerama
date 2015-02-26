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
      roll_value = randomizePinCountAfterReset
    
    # Handle second stroke for all frames
    elsif self.frame_stroke == 2 
      
      # Frames 1 through 9
      if self.current_frame < 10
        roll_value = randomizePinCountForSecondThrow
      
      # Frame 10
      elsif self.current_frame == 10
        
        if isLastStrokeStrike?
          roll_value = randomizePinCountAfterReset
        
        else
          roll_value = randomizePinCountForSecondThrow
        end

      end

  	# Handle third stroke for frame 10
	  elsif self.frame_stroke == 3 && self.current_frame == 10
      if isLastStrokeStrike? || isLastStrokeSpare?
      	roll_value = randomizePinCountAfterReset
      else
        roll_value = randomizePinCountForSecondThrow
      end
    end
    #insertRoll(roll_value)
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

  def randomizePinCountAfterReset
    self.bowled_pins = randomizePinCount( 0, 10 )
    self.pins_left = 10 - self.bowled_pins
    self.frames.where(frame_number: self.current_frame).update_all(pins_left: self.pins_left)
    return self.bowled_pins
  end

  def randomizePinCountForSecondThrow
    self.bowled_pins = randomizePinCount( 0, self.pins_left )
    self.pins_left = self.pins_left - self.bowled_pins
    self.frames.where(frame_number: self.current_frame).update_all(pins_left: self.pins_left)
    return self.bowled_pins
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
      insertRoll(10)

    # Handle Strikes and Spares for frame 10
    elsif self.current_frame == 10 && self.pins_left == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
        advanceFrameStroke!
      elsif self.frame_stroke == 2
        if isLastStrokeStrike?
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
        end
        advanceFrameStroke!
      elsif self.frame_stroke == 3
        if !isLastStrokeStrike? || !isLastStrokeSpare?
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "/")
        else
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "X")
        end
        endGame
      end
      insertRoll(10)

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
    
      insertRoll(0)

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

      insertRoll(0)

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

      insertRoll(self.bowled_pins)

    end

    calculateFrameScores!
    calculateTotalScore!
  end

  def isLastStrokeStrike?
  	if self.frame_stroke == 2 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.first_stroke == "X"
  			return true
  		end
  	elsif self.frame_stroke == 3 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.second_stroke == "X"
  			return true
  		end
  	elsif self.frame_stroke == 1
  		frame = self.getFrame(self.current_frame-1)
  		if frame.first_stroke == "X"
  			return true
  		end
    else
      false
  	end
  end

  def isLastStrokeSpare?
    if self.frame_stroke == 3 && self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  		if frame.second_stroke == "/"
  			return true
  		end
  	elsif self.frame_stroke == 1
  		frame = self.getFrame(self.current_frame-1)
  		if frame.second_stroke == "/"
  			return true
  		end
    else
      false
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

    self.rolls_will_change!
    self.rolls = []
    self.save!

    self.save
  end

  def getNextRoll(index)
    self.rolls[index+1]
  end

  def getNextRollValue(this_frame_number, this_frame_stroke)
    if this_frame_number < 10
      if this_frame_stroke == 1
        next_frame_value = getFrame(this_frame_number).second_stroke
      elsif this_frame_stroke == 2
        next_frame_value = getFrame(this_frame_number + 1).first_stroke
      end
    elsif this_frame_number == 10
      if this_frame_stroke == 1
        next_frame_value = getFrame(this_frame_number).second_stroke
      elsif this_frame_stroke == 2
        next_frame_value = getFrame(this_frame_number).extra_stroke
      end
    end
    return next_frame_value
  end

  def convertRollValue(frame_value)
    if (frame_value == "X") || (frame_value =="/")
      10
    elsif frame_value.nil?
      0
    else
      i.to_i
    end
  end

  def insertRoll(value)
    self.rolls_will_change!
    self.rolls << value
    self.save!
  end

  def loadRollValue
    roll_value = getNextRollValue
    roll_value = convertRollValue(roll_value)
    insertRoll(roll_value)
  end

  def getRollValueFor(index)
    if !self.rolls.any?
      roll_value = self.rolls[index]
    else
      0
    end
  end

  def scoreOpenFrame(this_frame_number)
    if self.getFrame(this_frame_number).first_stroke.nil?
      first_roll = 0
    else
      first_roll = self.getFrame(this_frame_number).first_stroke.to_i
    end

    if self.getFrame(this_frame_number).second_stroke.nil?
      second_roll = 0
    else
      second_roll = self.getFrame(this_frame_number).second_stroke.to_i
    end

    frame_score = first_roll + second_roll 
  end

  def scoreStrike(this_frame_number,this_frame_stroke)
    if self.getNextRollValue(this_frame_number, this_frame_stroke).nil?
      next_roll_value = 0
    else
      next_roll_value = self.getNextRollValue(this_frame_number, this_frame_stroke)
    end

    if this_frame_stroke == 1
      next_frame_stroke = 2
      next_frame_number = this_frame_number
    elsif this_frame_number < 10
      if this_frame_stroke == 2
        next_frame_stroke = 1
        next_frame_number = this_frame_number + 1
      end
    elsif this_frame_number == 10
      if this_frame_stroke == 2
        next_frame_stroke = 3
        next_frame_number = this_frame_number
      end
    end
      
    if self.getNextRollValue(next_frame_number, next_frame_stroke).nil?
      next_next_roll_value = 0
    else
      next_next_roll_value = self.getNextRollValue(this_frame_number, this_frame_stroke)
    end

    frame_score = 10 + next_roll_value + next_next_roll_value
  end

  def scoreSpare(this_frame_number, this_frame_stroke)
    if self.getNextRollValue(this_frame_number, this_frame_stroke).nil?
      next_roll_value = 0
    else
      next_roll_value = self.getNextRollValue(this_frame_number, this_frame_stroke)
    end

    frame_score = 10 + next_roll_value
  end

  def calculateFrameScore!
    self.frames.each { |frame|
      index = convertFrameToIndex(frame)

      if frame.isStrike?
        frame_score = self.scoreStrike(index)
      elsif frame.isStrike?
        frame_score = self.scoreSpare(index)
      elsif frame.isOpenFrame?
        frame_score = self.scoreOpenFrame(frame.frame_number)
      end

      self.frames.where(frame_number: frame.frame_number ).update_all(frame_score: frame_score)
    }
    self.save
  end

  def calculateFrameScores!
    
    i = 1

    while i <= self.current_frame
      current_frame = self.getFrame(i)

      if current_frame.isStrike?
        frame_score = self.scoreStrike(current_frame.frame_number, self.current_frame_number)
      elsif current_frame.isStrike?
        frame_score = self.scoreSpare(current_frame.frame_number, self.current_frame_number)
      elsif current_frame.isOpenFrame?
        frame_score = self.scoreOpenFrame(current_frame.frame_number)
      end

      self.frames.where(frame_number: current_frame.frame_number ).update_all(frame_score: frame_score)

      self.save

      i += 1
    end
  end

  def calculateTotalScore!
    self.total_score = self.getFrame(self.current_frame).frame_score + self.getFrame(self.current_frame+1).frame_score
    self.save
  end

  def convertFrameToIndex(frame)
    frame_number = frame.frame_number
    case frame_number
    when 1
      if self.frame_stroke
        index = 0
      elsif !frame.second_stroke.nil?
        index = 1
      end
    when 2
      if !frame.first_stroke.nil?
        index = 2
      elsif !frame.second_stroke.nil?
        index = 3
      end
    when 3
      if !frame.first_stroke.nil?
        index = 4
      elsif !frame.second_stroke.nil?
        index = 5
      end
    when 4
      if !frame.first_stroke.nil?
        index = 6
      elsif !frame.second_stroke.nil?
        index = 7
      end
    when 5
      if !frame.first_stroke.nil?
        index = 8
      elsif !frame.second_stroke.nil?
        index = 9
      end
    when 6
      if !frame.first_stroke.nil?
        index = 10
      elsif !frame.second_stroke.nil?
        index = 11
      end
    when 7
      if !frame.first_stroke.nil?
        index = 12
      elsif !frame.second_stroke.nil?
        index = 13
      end
    when 8
      if !frame.first_stroke.nil?
        index = 14
      elsif !frame.second_stroke.nil?
        index = 15
      end
    when 9
      if !frame.first_stroke.nil?
        index = 16
      elsif !frame.second_stroke.nil?
        index = 17
      end
    when 10
      if !frame.first_stroke.nil?
        index = 18
      elsif !frame.second_stroke.nil?
        index = 19
      else
        index = 20
      end
    end
    index = 21
  end
end
