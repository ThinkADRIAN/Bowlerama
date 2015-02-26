class Frame < ActiveRecord::Base
	belongs_to :game

  def setScore!(bowled_pins)
    self.updateFrameScore!(bowled_pins)

    # Handle 2 strikes in a row
    if getFrame(-1).isStrike? and getFrame(-2).isStrike?

      # First stroke of current frame
    	if second_stroke.nil?
      	getFrame(-2).updateFrameScore!(bowled_pins)
      end

      # Second stroke of current frame
      if extra_stroke.nil?
       getFrame(-1).updateFrameScore!(bowled_pins)
     	end

    # Handle strike in previous frame on completion of current frame
    elsif getFrame(-1).isStrike? and extra_stroke.nil?
      getFrame(-1).updateFrameScore!(bowled_pins)

    # Handle spare in previous frame after first stroke of current frame
    elsif getFrame(-1).isSpare? and second_stroke.nil?
      getFrame(-1).updateFrameScore!(bowled_pins)
    end
  end

  # returns a relative frame to the current one
  def getFrame(frames_to_shift)
    adjustment_for_frame_indexing = 1
    game.frames[game.current_frame + frames_to_shift - adjustment_for_frame_indexing]
  end

  # increments a frame's score
  def updateFrameScore!(score)
    self.frame_score += score
    self.save
  end

  def isStrike?
    self.first_stroke == "X" ||
    self.second_stroke == "X" ||
    self.extra_stroke == "X"
  end

  def isSpare?
    self.second_stroke == "/" ||
    self.extra_stroke == "/"
  end

  def isOpenFrame?
    if self.pins_left != 0
      true
    else
      false
    end
  end
end
