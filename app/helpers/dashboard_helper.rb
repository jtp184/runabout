module DashboardHelper
  def source_url(page)
    "https://memory-alpha.fandom.com/wiki/" + ERB::Util.url_encode(page.to_s.tr(" ", "_"))
  end

  def photo_for(record)
    Enrichment::Photo.new(record).path
  end

  def timecode(seconds)
    seconds = seconds.to_f.to_i.clamp(0, 999_999)
    "%02d:%02d" % [ seconds / 60, seconds % 60 ]
  end

  def permitted_control?(state, action)
    capability = { "Play" => "CanPlay", "Pause" => "CanPause", "Next" => "CanGoNext", "Previous" => "CanGoPrevious", "SetPosition" => "CanSeek" }[action]
    state.bus_name.present? && state.capabilities["CanControl"] && (!capability || state.capabilities[capability])
  end
end
