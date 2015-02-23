class Frame < ActiveRecord::Base
	belongs_to :game

  # returns a relative frame to the current one
  def getFrame(frames_to_shift)
    game.frames[game.current_frame_number + frames_to_shift]
  end

  # increments a frame's score
  def updateScore(score)
    self.frame_score += score
    self.save
  end

  def setScore!(number_of_pins)
    self.updateScore!(number_of_pins)

    if getFrame(-1).isStrike? and getFrame(-2).isStrike?
    	if second_stroke.nil? #
      	getFrame(-2).updateScore(number_of_pins)
      end
      if extra_stroke.nil? #
       getFrame(-1).updateScore(number_of_pins)
     	end
    elsif getFrame(-1).isStrike? and extra_stroke.nil? # == ""
      getFrame(-1).updateScore(number_of_pins)
    elsif get_frame(-1).isSpare? and second_stroke.nil? #
      getFrame(-1).updateScore(number_of_pins)
    end
  end

  def isStrike?
    self.first_stroke == "X" || self.second_stroke == "X" ||  self.extra_stroke == "X"
  end

  def is_spare?
    self.second_stroke == "/" ||  self.extra_stroke == "/"
  end
end
