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

	def rollBall(game_type)

    self.resetPinsIfNecessary!

    # Random Game
    if game_type == "random"
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
    
    # The Perfect Game
    elsif game_type == "perfect"
      roll_value = bowlStrike
    
    # Only Miss First Frame and "Pickup" the remaining pins
    elsif game_type == "pickup"
      if self.frame_stroke == 1
        self.bowled_pins = rand(0..9)
        self.pins_left = 10 - self.bowled_pins
        self.frames.where(frame_number: self.current_frame).update_all(pins_left: self.pins_left)
        roll_value = self.bowled_pins
      elsif self.frame_stroke == 2
        roll_value = bowlSpare
      else
        roll_value = bowlStrike
      end

    # Scorecard with -, /, X
    elsif game_type == "marker"
      if self.frame_stroke == 1 && self.current_frame.odd?
        roll_value = bowlZero
      elsif self.frame_stroke == 2 && self.current_frame < 10
        roll_value = bowlSpare
      else
        roll_value = bowlStrike
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

  def bowlStrike
    self.bowled_pins = self.pins_left
    self.pins_left = 0
    self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
    return self.bowled_pins
  end

  def bowlSpare
    self.bowled_pins = self.pins_left
    self.pins_left = 0
    self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
    return self.bowled_pins
  end

  def bowlZero
    self.bowled_pins = 0
    self.pins_left = 10 - self.bowled_pins
    self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
    return self.bowled_pins
  end

  def randomizePinCount( start_value, finish_value )
    return rand( start_value..finish_value )
  end

  def randomizePinCountAfterReset
    self.bowled_pins = randomizePinCount( 0, 10 )
    self.pins_left = 10 - self.bowled_pins
    self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
    return self.bowled_pins
  end

  def randomizePinCountForSecondThrow
    self.bowled_pins = randomizePinCount( 0, self.pins_left )
    self.pins_left = self.pins_left - self.bowled_pins
    self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
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

  def markScoreStrikeOrSpare
    # Handle Strikes and Spares for frames 1 through 9
    if self.current_frame < 10
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
        insertRoll(10)
        insertRoll(0)
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
        insertRoll(10)
      end
      self.frame_stroke = 1
      incrementFrameCount!
      #insertRoll(10)
    # Handle Strikes and Spares for frame 10
    elsif self.current_frame == 10
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
        advanceFrameStroke!
      elsif self.frame_stroke == 2
        if self.rolls.last == 10
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
        end
        advanceFrameStroke!
      elsif self.frame_stroke == 3
        if self.rolls.last == 10
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "/")
        end
        endGame
      end
      insertRoll(10)
    end
  end

  def markScoreZero
    # Handle Zero pins bowled in frame 10
    if self.current_frame == 10
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
    end
  end

  def markScoreOpen
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

  def markScorecard!
    if self.pins_left == 0
      markScoreStrikeOrSpare
    elsif self.bowled_pins == 0
      markScoreZero
    else
      markScoreOpen
    end
  end

  def isLastStrokeStrike?
    if self.frame_stroke == 1
      frame = self.getFrame(self.current_frame-1)
      if frame.first_stroke == "X"
        return true
      end
    elsif self.frame_stroke == 2
      frame = self.getFrame(self.current_frame)
      if frame.first_stroke == "X"
        return true
      end
    elsif self.frame_stroke == 3 
      frame = self.getFrame(self.current_frame)
      if frame.second_stroke == "X"
        return true
      end
    else
      false
  	end
  end

  def isLastStrokeSpare?
    if self.frame_stroke == 1
      frame = self.getFrame(self.current_frame-1)
      if frame.second_stroke == "/"
        return true
      end
    elsif self.frame_stroke == 2
      frame = self.getFrame(self.current_frame)
      if frame.first_stroke == "/"
        return true
      end
    elsif self.frame_stroke == 3
  		frame = self.getFrame(self.current_frame)
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

  def insertRoll(value)
    self.rolls_will_change!
    self.rolls << value
    self.save!
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

  def convertRollValue(frame_value)
    if (frame_value == "X") || (frame_value =="/")
      10
    elsif frame_value.nil?
      0
    else
      i.to_i
    end
  end

  def subZeroForNil( value )
    if value.nil?
      0
    else
      value
    end
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
    
  def getNextFrameNumber(this_frame_number, this_frame_stroke)
    if this_frame_stroke == 1
      next_frame_number = this_frame_number
    elsif this_frame_number < 10
      if this_frame_stroke == 2
        next_frame_number = this_frame_number + 1
      end
    elsif this_frame_number == 10
      if this_frame_stroke == 2
        next_frame_number = this_frame_number
      end
    end
  end

  def getNextStrokeNumber(this_frame_number, this_frame_stroke)
    if this_frame_stroke == 1
      next_frame_stroke = 2
    elsif this_frame_number < 10
      if this_frame_stroke == 2
        next_frame_stroke = 1
      end
    elsif this_frame_number == 10
      if this_frame_stroke == 2
        next_frame_stroke = 3
      end
    end
  end

  def scoreOpenFrame(this_frame_number)
    first_roll = subZeroForNil(self.getFrame(this_frame_number).first_stroke).to_i
    second_roll = subZeroForNil(self.getFrame(this_frame_number).second_stroke).to_i
    frame_score = first_roll + second_roll 
  end

  def scoreBonus(this_frame_number,this_frame_stroke, this_roll_value)
    if this_roll_value = "X"
      this_roll_value = scoreStrike(this_frame_number, this_frame_stroke)
    elsif this_roll_value = "/"
      this_roll_value = scoreSpare(this_frame_number, this_frame_stroke)
    else
      this_roll_value = scoreOpenFrame(this_frame_number)
    end
    this_roll_value = convertRollValue(this_roll_value)
  end

  def scoreStrike(this_frame_number,this_frame_stroke)
    next_roll_value = subZeroForNil(self.getNextRollValue(this_frame_number, this_frame_stroke))

    next_frame_number = getNextFrameNumber(this_frame_number, this_frame_stroke)
    next_stroke_number = getNextStrokeNumber(this_frame_number, this_frame_stroke)
      
    next_next_roll_value = subZeroForNil(self.getNextRollValue(next_frame_number, next_stroke_number))

    next_roll_value = scoreBonus(next_frame_number, next_stroke_number, next_roll_value)

    frame_score = 10 + next_roll_value + next_next_roll_value
  end

  def scoreSpare(this_frame_number, this_frame_stroke)
    next_roll_value = subZeroForNil(self.getNextRollValue(this_frame_number, this_frame_stroke))

    next_frame_number = getNextFrameNumber(this_frame_number, this_frame_stroke)
    next_stroke_number = getNextStrokeNumber(this_frame_number, this_frame_stroke)

    next_roll_value = scoreBonus(next_frame_number, next_stroke_number, next_roll_value)

    frame_score = 10 + next_roll_value
  end

  def calculateFrameScores!
    current_frame = getFrame(self.current_frame)
    
    if current_frame.isStrike?
      frame_score = self.scoreStrike(current_frame.frame_number, self.frame_stroke)
    elsif current_frame.isSpare?
      frame_score = self.scoreSpare(current_frame.frame_number, self.frame_stroke)
    elsif current_frame.isOpenFrame?
      frame_score = self.scoreOpenFrame(current_frame.frame_number)
    end
    
    self.frames.where(frame_number: current_frame.frame_number ).update_all(frame_score: frame_score)
    self.save
  end

  def calculateTotalScore!
    self.total_score = self.rolls.inject{|sum,x| sum + x }
  end

  def getFrameScore(index)
    if index < 18
      if self.rolls[index] == 10
        if index.even?
          # Handle Strike
          return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
        else index.odd?
          # Handle Spare
          return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1])
        end
      else
        # Handle Open Frame for First Stroke
        if index.even?
          return subZeroForNil(self.rolls[index])
        # Handle Open Frame for Second Stroke
        else index.odd?
          return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index-1])
        end
      end
    elsif index == 18
      if self.rolls[index] == 10
        # Handle Strike
        return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
      else
        # Handle Open Frame
        return subZeroForNil(self.rolls[index])
      end
    elsif index == 19
      if self.rolls[index] == 10
        if self.rolls[index-1] == 10
          # Handle Strike
          return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
        else
          # Handle Spare
          return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1])
        end
      else
        # Handle Open Frame
        return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index-1])
      end
    elsif index == 20
      return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index-1]) + subZeroForNil(self.rolls[index-2])
    end
  end

  def assignFrameScores!
    index = 0
    frame_number = 1

    while index <= 20 and frame_number <= self.current_frame
      frame_score = getFrameScore(index)
      self.frames.where(frame_number: frame_number).update_all(frame_score: frame_score)
      self.save
      if index.odd? && index < 18
        frame_number += 1
      elsif index >= 18
        frame_number = 10
      end
      index += 1
    end
  end

  def calculateGameDetails
    # calculateFrameScores!
    # assignFrameScores!
    # calculateTotalScore!
    setFrameScoreArray
    #calculateArrayScores
  end

  def isStrikeWithArrayIndex?(index)
    if self.rolls[index] == 10
      if index <= 18 && (index.even? || index == 0)
        return true
      elsif index == 19 && self.rolls[18] == 10
        return true
      elsif index == 20 && self.rolls[19] == 10
        return true
      end
    else
      false
    end
  end

  def isSpareWithArrayIndex?(index)
    if self.rolls[index] == 10
      if index < 18 && index.odd?
        return true
      elsif index == 19 && self.rolls[18] < 10
        return true
      elsif index == 20 && self.rolls[19] < 10
        return true
      end
    else
      false
    end
  end

  def getFrameScoreArray(index, frame_number)
    if isStrikeWithArrayIndex?(index)
      if index < 15
        if isStrikeWithArrayIndex?(index+2) && isStrikeWithArrayIndex?(index+4)
          return 30
        elsif isStrikeWithArrayIndex?(index+2) && isSpareWithArrayIndex?(index+3)
          return 20
        else
          return 10 + subZeroForNil(self.rolls[index+2]) + subZeroForNil(self.rolls[index+3])
        end
      elsif index == 16
        if isStrikeWithArrayIndex?(index+2) && isStrikeWithArrayIndex?(index+3)
          return 30
        elsif isStrikeWithArrayIndex?(index+2) && isSpareWithArrayIndex?(index+3)
          return 20
        else
          return 10 + subZeroForNil(self.rolls[index+2]) + subZeroForNil(self.rolls[index+3])
        end
      elsif index == 18
        if isStrikeWithArrayIndex?(index+1) && isStrikeWithArrayIndex?(index+2)
          return 30
        else
          return 10 + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
        end
      elsif index == 19
        if isStrikeWithArrayIndex?(index+1)
          return 30
        else
          return 10 + subZeroForNil(self.rolls[index+1])
        end
      elsif index == 20
        # XXX
        if isStrikeWithArrayIndex?(18) && isStrikeWithArrayIndex?(19) && isStrikeWithArrayIndex?(20)
          return 30
        # XX#
        elsif isStrikeWithArrayIndex?(18) && isStrikeWithArrayIndex?(19)
          return 20 + subZeroForNil(self.rolls[20])
        # X#/
        elsif isStrikeWithArrayIndex?(18) && isSpareWithArrayIndex?(20)
          return 20
        # X##
        else 
          return 10 + self.rolls[19] + self.rolls[20]
        end
      end
    elsif isSpareWithArrayIndex?(index)
      if index < 19
        return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1])
      elsif index == 19
        if isStrikeWithArrayIndex?(20)
          return 20
        else
          return 10 + subZeroForNil(self.rolls[20])
        end
      elsif index == 20
         return 20
      end 
    elsif index == 18
      if isStrikeWithArrayIndex?(18)
        return 10
      else
        return self.rolls[18]
      end
    elsif index.even?
      return subZeroForNil(self.rolls[index])
    elsif index.odd?
      return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index-1])
    end
  end

  def setFrameScoreArray
    index = 0
    frame_number = 1

    while index <= 20 && frame_number <= 10
      frame_score = getFrameScoreArray(index, frame_number)
      self.frames.where(frame_number: frame_number).update_all(frame_score: frame_score)
      self.save
      if isStrikeWithArrayIndex?(index)
        if index < 17
          index += 2
          frame_number += 1
        elsif index >= 17
          index += 1
        end
      elsif index.odd?
        if index < 18
          frame_number += 1
        end
        index += 1
      elsif index.even?
        index += 1
      end
    end
  end

  def calculateArrayScores
    score = 0
    index = 0

    while index < 20
      if isStrikeWithArrayIndex?(index)
        if isStrikeWithArrayIndex?(index+1) && isStrikeWithArrayIndex?(index+2)
          score += 30
        else
          score += subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
        end
      elsif isSpareWithArrayIndex?(index)
        score += subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index+1])
      else
        score += subZeroForNil(self.rolls[index])
      end
      index += 1
    end

    self.total_score = score
  end
end