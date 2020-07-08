
# module PatternMatching

#   def self.included( klass )
#     puts "PatternMatching.included #{klass.inspect}"

#     ASCII_ALPHANUMERIC = (65..90).to_a + (97..122).to_a + [95]
#     def klass.match( *args )
#       method = args.pop
#       puts "PatternMatching #{self.inspect}.match #{method} #{args.inspect}"

#       sig = args.map{|a| a.inspect }.join('_')
#       sig.each_char.each_with_index(){|c,i| sig[i] = ASCII_ALPHANUMERIC.include?(c.ord) ? c : "_" }
#       puts "sig: #{sig}"
#     end

#   end


# end

# class PmTest
#   include PatternMatching

#   match def test
#     puts "it's nothing"
#   end

#   match String, def test(str)
#     puts "it's String : #{str}"
#   end

#   match "fuck", def test(str)
#     puts "it's fuck : #{str}"
#   end

# end



#   PmTest.new.test
#   PmTest.new.test("hello")
#   PmTest.new.test("fuck")

#   