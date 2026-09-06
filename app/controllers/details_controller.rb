class DetailsController < ApplicationController
  def entity
    @subject = Entity.current.find_by(id: params[:id])
    show_subject
  end

  def person
    @subject = Person.current.find_by(id: params[:id])
    EnrichPhotoJob.perform_later("person", @subject.id) if @subject && ENV["TMDB_API_KEY"].present? && @subject.photo_data.blank?
    show_subject
  end

  def article
    @page = params[:page].to_s.tr("_", " ").first(255)
    @subject = Entity.current.find_by(page: @page) || Person.current.find_by(page: @page) || Episode.current.find_by(page: @page)
    show_subject
  end

  def close
  end

  private

  def show_subject
    @page ||= @subject&.page
    if @page.present?
      @article = MemoryAlpha::ArticleCache.new.fetch(@page)
    end
    render :show
  end
end
