require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Filter do

  describe "creation" do
    it "should fail" do
      Filter.new.should_not be_valid
    end
  end
  
  describe "destruction through obsolescence" do
    before(:all) do
      recent, old = 2.minutes.ago, (CachedFind::OBSOLESCENCE_TIME + 2.minutes).ago

      @finds = [[nil, recent], [nil, old], [1, recent], [1, old]].map do |user_id, executed_at|
        CachedFind.create(:user_id => user_id, :executed_at => executed_at,
                          :language_code => "ENG", :specification => "test")
      end

      @finds.each do |find|
        TextFilter.create(:cached_find_id => find.id, :property_definition_id => 1, :language_code => "ENG")
      end
    end

    after(:all) do
      @finds.each { |find| find.destroy }
    end

    it "should remove only those filters belonging to an archived CachedFind" do
      Filter.archived.each { |filter| filter.destroy }
      @finds.map { |find| find.filters.count }.should == [1, 0, 1, 1]
    end
  end

end