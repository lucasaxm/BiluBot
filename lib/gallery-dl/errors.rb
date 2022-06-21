module GalleryDL
  class GalleryDlError < StandardError
    def initialize(msg="Error running GalleryDl")
      super(msg)
    end
  end
  class GalleryDlTimeout < StandardError
    def initialize(msg="Timeout running GalleryDl")
      super(msg)
    end
  end
end