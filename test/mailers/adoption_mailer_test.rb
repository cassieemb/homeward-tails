require "test_helper"

class AdoptionMailerTest < ActionMailer::TestCase
  test "new adoption" do
    match = create(:match, match_type: :adoption)
    email = AdoptionMailer.new_adoption(match)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [match.person.email], email.to
    assert_equal [Rails.application.config.from_email], email.from
    assert_match(/#{match.pet.name}/, email.subject)
    assert_match(/#{match.pet.name}/, email.body.encoded)
  end
end
