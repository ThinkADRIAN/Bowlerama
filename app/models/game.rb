class Game < ActiveRecord::Base
	has_many :frames, :dependent => :destroy
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
		self.resetPinsIfNecessary

    # Handle first stroke for all frames
    if self.frame_stroke == 1 && self.current_frame <= 10
      self.bowled_pins = randomizePinCount( 0, 10 )
      self.pins_left = 10 - self.bowled_pins
    
    # Handle second stroke for frames 1 through 9
    elsif self.frame_stroke == 2 && self.current_frame < 10
      self.bowled_pins = randomizePinCount( 0, self.pins_left )
      self.pins_left = self.pins_left - self.bowled_pins

    # Handle second and third stroke for frame 10  
    elsif self.frame_stroke != 1 && self.current_frame == 10
      if isLastTurnStrike?()  || isLastTurnSpare?()
        self.bowled_pins = randomizePinCount( 0, 10 )
        self.pins_left = 10 - self.bowled_pins
      else
        self.bowled_pins = randomizePinCount( 0, 10 )
        self.pins_left = 10 - self.bowled_pins
      end
    end
	end

	def incrementFrameCount
    if self.current_frame < 10
      self.current_frame += 1
    end
  end

  def createNewFrame
      frame = self.frames.create(frame_number: self.current_frame)
      self.frames << frame
  end

  def resetPinsIfNecessary
    if ( self.frame_stroke == 1 && self.current_frame < 10 ) || isLastTurnStrike? || isLastTurnSpare?
      @pins_left = 10
      @bowled_pins = 0
    end
  end

  def randomizePinCount( start_value, finish_value )
    return rand( start_value..finish_value )
  end

  def advanceFrameStroke
    if self.frame_stroke == 1
      self.frame_stroke = 2
    else
      self.frame_stroke = 1
    end
  end

  def endGame
    self.frame_stroke = -1
  end

  def markScorecard
    # Handle Strikes and Spares for frames 1 through 9
    if self.current_frame < 10 && self.pins_left == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
      end
      self.frame_stroke = 1
      self.incrementFrameCount
    # Handle Strikes and Spares for frame 10
    elsif self.current_frame == 10 && @pins_left == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "X")
        self.incrementFrameCount
      elsif self.frame_stroke == 2
        if isLastTurnStrike?
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "/")
        end
        endGame
      elsif self.frame_stroke == 3
        if isLastTurnStrike? || isLastTurnSpare?
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "X")
        else
          self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "/")
        end
        endGame
      end
    
    # Handle Zero pins bowled
    elsif self.bowled_pins == 0
      if self.frame_stroke == 1
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: "-")
        advanceFrameStroke
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: "-")
        advanceFrameStroke
        self.incrementFrameCount
      elsif self.frame_stroke == 3
        self.frames.where(frame_number: self.current_frame).update_all(extra_stroke: "-")
        endGame
      end
    # Handle all other strokes
    else
      if self.frame_stroke == 1 
        self.frames.where(frame_number: self.current_frame).update_all(first_stroke: self.bowled_pins)
        advanceFrameStroke
      elsif self.frame_stroke == 2
        self.frames.where(frame_number: self.current_frame).update_all(second_stroke: self.bowled_pins)
        advanceFrameStroke
        self.incrementFrameCount
        if self.current_frame == 10
          endGame
        end
      else
        endGame
      end
    end
    self.calculateTotalScore
  end

  def isLastTurnStrike?
    isStrike?(self.current_frame-1)
  end

  def isLastTurnSpare?
    isSpare?(self.current_frame-1)
  end

  def isStrike?(frame_to_check)
    self.frames.where(frame_number: frame_to_check, first_stroke: "X") ||
    self.frames.where(frame_number: frame_to_check, second_stroke: "X")
  end

  def isSpare?(frame_to_check)
    self.frames.where(frame_number: frame_to_check, second_stroke: "/") || 
    self.frames.where(frame_number: frame_to_check, extra_stroke: "/")
  end

  def calculateTotalScore
    # Calculate the sum of values in @frame_scores
    self.total_score = 0
    self.frames.each { |frame| self.total_score += frame.frame_score unless frame.frame_score.nil? }
    self.total_score
  end

  def isGameOver
    self.frame_stroke == -1
  end

  def getFrame(frame_number)
  	self.frames.each { |frame| 
  		if frame.frame_number == frame_number
  			return frame
  		end
  	}
  end
end
