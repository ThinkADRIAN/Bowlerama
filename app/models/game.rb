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
    loadPinfallArray!
    #convertPinfallArray!(calculateFrameScores!)
    #calculateScores!(self.rolls)
    calculateFrameScores!
    calculateTotalScore
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

  def calculateTotalScore!
  	if self.current_frame == 1 || (self.current_frame > 1 && self.frame_stroke > 1) || self.current_frame == 10
  		frame = self.getFrame(self.current_frame)
  	elsif self.frame_stroke == 1
  		frame = self.getFrame(self.current_frame-1)
  	end
  	frame.setScore!(self.bowled_pins)
    # Calculate the sum of values in @frame_scores
    self.total_score = 0
    self.frames.each { |frame| self.total_score += frame.frame_score unless frame.frame_score.nil? }
    self.total_score
  end  

  def loadPinfallArray!
    pinfall_array = []

    i = 1
    10.times { 
      insert_frame = self.getFrame(i)

      if insert_frame.first_stroke == ""
        pinfall_array << 0
      else
        pinfall_array << insert_frame.first_stroke
      end

      if insert_frame.second_stroke == ""
        pinfall_array << 0
      else
        pinfall_array << insert_frame.second_stroke
      end

      if i == 10
        if insert_frame.extra_stroke == ""
          pinfall_array << 0
        else
          pinfall_array << insert_frame.extra_stroke
        end
      end
      i += 1
    }
    self.rolls = pinfall_array
    self.save
  end

  def convertPinfallArray!(pinfall_array)
    pinfall_array.map! { |i|
      if (i == "X") || (i =="/")
        10
      else
        i.to_i
      end
    }
  end

  def calculateScores!(pinfall_array)

    # Initialize variables
    i_frame = 0
    @frame_scores = []

    while i_frame <= 9 do 

      # Load First Pinfall
      @frame_scores[i_frame] = pinfall_array.shift

      # Check for Strike
      if @frame_scores[i_frame] == 10
        # Add Next Pinfalls
        @frame_scores[i_frame] = (10 + pinfall_array[0] + pinfall_array[1])

      # Handle if not Strike
      else
        # Add Next Pinfall
        @frame_scores[i_frame] = @frame_scores[i_frame] + pinfall_array.shift 

        # Check for Strike
        if @frame_scores[i_frame] == 10
          @frame_scores[i_frame] = (10 + pinfall_array[0])
        end
      end

      # Set Frame Score
      i_frame +=1
      self.frames.where(frame_number: i_frame ).update_all(frame_score: @frame_scores[i_frame-1])

    end
    # Set Total Score
    self.total_score = @frame_scores.inject{|sum,x| sum + x }
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

  def insertRoll(value)
    self.rolls << value
  end

  def getNextRoll(index)
    self.rolls[index+1]
  end

  def scoreOpenFrame(index)
    frame_score = self.rolls[index].to_i + self.rolls[index+1].to_i
  end

  def scoreStrike(index)
    next_roll = getNextRoll(index).to_i
    next_next_roll = getNextRoll(index+1).to_i

    frame_score = 10 + next_roll + next_next_roll 
  end

  def scoreSpare(index)
    next_roll = getNextRoll(index)

    frame_score = 10 + next_roll.to_i
  end

  def calculateFrameScores!
    self.frames.each { |frame|
      index = convertFrameToIndex(frame)

      if frame.isStrike?
        self.rolls[index] = self.scoreStrike(index)
      elsif frame.isStrike?
        self.rolls[index] = self.scoreSpare(index)
      elsif frame.isOpenFrame?
        self.rolls[index] = self.scoreOpenFrame(index)
      end

      self.frames.where(frame_number: frame.frame_number ).update_all(frame_score: self.rolls[index])
    }
    self.save
  end

  def calculateTotalScore
    self.frames.each { |frame|
      self.total_score = frame.frame_score.to_i
    }
    self.save
  end

  def convertFrameToIndex(frame)
    frame_number = frame.frame_number
    case frame_number
    when 1
      if frame.second_stroke.nil?
        index = 0
      elsif frame.extra_stroke.nil?
        index = 1
      end
    when 2
      if frame.second_stroke.nil?
        index = 2
      elsif frame.extra_stroke.nil?
        index = 3
      end
    when 3
      if frame.second_stroke.nil?
        index = 4
      elsif frame.extra_stroke.nil?
        index = 5
      end
    when 4
      if frame.second_stroke.nil?
        index = 6
      elsif frame.extra_stroke.nil?
        index = 7
      end
    when 5
      if frame.second_stroke.nil?
        index = 8
      elsif frame.extra_stroke.nil?
        index = 9
      end
    when 6
      if frame.second_stroke.nil?
        index = 10
      elsif frame.extra_stroke.nil?
        index = 11
      end
    when 7
      if frame.second_stroke.nil?
        index = 12
      elsif frame.extra_stroke.nil?
        index = 13
      end
    when 8
      if frame.second_stroke.nil?
        index = 14
      elsif frame.extra_stroke.nil?
        index = 15
      end
    when 9
      if frame.second_stroke.nil?
        index = 16
      elsif frame.extra_stroke.nil?
        index = 17
      end
    when 10
      if frame.second_stroke.nil?
        index = 18
      elsif frame.extra_stroke.nil?
        index = 19
      else
        index = 20
      end
    end
    return index
  end
end
