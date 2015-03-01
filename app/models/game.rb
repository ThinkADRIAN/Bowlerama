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
        self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
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

    # All Strikes excpet the last stroke
    elsif game_type == "choker"
      if self.frame_stroke == 3
        self.bowled_pins = rand(0..9)
        self.pins_left = 10 - self.bowled_pins
        self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
        roll_value = self.bowled_pins
      else
        roll_value = bowlStrike
      end

    # No pins bowled ever
    elsif game_type == "gutter"
      self.bowled_pins = 0
      self.pins_left = 10
      self.frames.where(frame_number: self.current_frame).update_all(bowled_pins: self.bowled_pins, pins_left: self.pins_left)
      roll_value = self.bowled_pins
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
  end

  def subZeroForNil( value )
    if value.nil?
      0
    else
      value
    end
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

  def getFrameScore(index, frame_number)
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
        return 10 + subZeroForNil(self.rolls[index+1]) + subZeroForNil(self.rolls[index+2])
      elsif index == 19
        if isStrikeWithArrayIndex?(index-1)
          return 20
        else
          return 10
        end
      elsif index == 20
        # XXX
        if isStrikeWithArrayIndex?(18) && isStrikeWithArrayIndex?(19)
          return 30
        # XX#
        elsif isStrikeWithArrayIndex?(18) && isStrikeWithArrayIndex?(19) && self.rolls[20] < 10
          return 20 + subZeroForNil(self.rolls[20])
        # X#/
        elsif isStrikeWithArrayIndex?(18) && self.rolls[19] < 10 && isSpareWithArrayIndex?(20)
          return 20
        # #/X
        elsif self.rolls[18] < 10 && isSpareWithArrayIndex?(19)
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
        return 10
      elsif index == 20
         return 20
      end 
    elsif index == 18
      if isStrikeWithArrayIndex?(18)
        return 10
      else
        return self.rolls[18]
      end
    elsif index == 19
      return subZeroForNil(self.rolls[18]) + subZeroForNil(self.rolls[19])
    elsif index == 20
      return subZeroForNil(self.rolls[18]) + subZeroForNil(self.rolls[19]) + subZeroForNil(self.rolls[20])
    elsif index.even?
      return subZeroForNil(self.rolls[index])
    elsif index.odd?
      return subZeroForNil(self.rolls[index]) + subZeroForNil(self.rolls[index-1])
    end
  end

  def setFrameScores!
    index = 0
    frame_number = 1
    score = 0 

    while index <= 20 && frame_number <= 10
      frame_score = getFrameScore(index, frame_number)
      self.frames.where(frame_number: frame_number).update_all(frame_score: frame_score)
      self.save!
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

  def calculateTotalScore!
    score = 0
    self.frames.each do |frame|
      score += self.subZeroForNil(frame.frame_score)
    end

    self.total_score = score
    self.save!
  end

  def bowl!(game_type)
    rollBall(game_type)
    markScorecard!
    setFrameScores!
    calculateTotalScore!
  end
end