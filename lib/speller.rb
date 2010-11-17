# inspired by Peter Norvig's spelling corrector
# see http://norvig.com/spell-correct.html

class Speller
  def initialize(frequencies_by_words, alphabet = ('a'..'z').to_a, max_distance = 1)
    @alphabet = alphabet
    @corrections_by_word = {}
    @frequencies_by_words = Hash[frequencies_by_words.map { |word, freq| [word, freq + 1] }]
    @frequencies_by_words.default = 1
    @known_words = frequencies_by_words.keys.to_set
    @max_distance = max_distance
  end
  
  def correct(word)
    return @corrections_by_word[word] if @corrections_by_word.has_key?(word)
    @corrections_by_word[word] = _correct(word)
  end
  
  
  private
  
  def _correct(word)
    return word if @known_words.include?(word)
    
    edits = [word]
    1.upto(@max_distance) do |i|
      edits = edits.map { |e| generate_edits(e) }.flatten
      known_edits = (@known_words & edits)
      return known_edits.max { |a, b| @frequencies_by_words[a] <=> @frequencies_by_words[b] } unless known_edits.empty?
    end
    
    nil
  end
  
  def generate_edits(word)
    splits = 0.upto(word.size).map { |i| [word[0, i], word[i..-1]] }
    
    deletes    = splits.map { |a, b| b.size > 0 ? a + b[1..-1] : nil }.compact
    transposes = splits.map { |a, b| b.size > 1 ? a + b[1].chr + b[0].chr + b[2..-1] : nil }.compact
    replaces   = splits.map { |a, b| b.size > 0 ? @alphabet.map { |c| a + c + b[1..-1] } : nil }.compact.flatten
    inserts    = splits.map { |a, b| @alphabet.map { |c| a + c + b } }.flatten
    
    (deletes + transposes + replaces + inserts).uniq
  end
end
