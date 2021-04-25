require "pg"
require "db"

require "./version"

module PostGIS
  abstract struct Geography
    def self.from_ewkb(io : IO, endian : IO::ByteFormat)
      # TODO: Come up with a better way to distinguish this. Maybe generics?
      # I'm not sure of the best way to do it yet, I was just trying to come up
      # with something that worked.
      case type = io.read_bytes UInt32, endian
      when 0x20000001 then Point2D
      when 0xA0000001 then Point3D
      when 0x20000003 then Polygon2D
      else
        raise DecodingError.new("Unsupported geography type: #{type.to_s(16)}")
      end.from_ewkb(io, endian)
    end
  end

  struct Point2D < Geography
    getter x : Float64
    getter y : Float64
    getter srid : UInt32

    def self.from_ewkb(io, endian : IO::ByteFormat) : self
      new(
        srid: io.read_bytes(UInt32, endian),
        x: io.read_bytes(Float64, endian),
        y: io.read_bytes(Float64, endian),
      )
    end

    def initialize(@x, @y, @srid = 4326_u32)
    end
  end

  struct Point3D < Geography
    getter x : Float64
    getter y : Float64
    getter z : Float64
    getter srid : UInt32

    def self.from_ewkb(io, endian : IO::ByteFormat) : self
      new(
        srid: io.read_bytes(UInt32, endian),
        x: io.read_bytes(Float64, endian),
        y: io.read_bytes(Float64, endian),
        z: io.read_bytes(Float64, endian),
      )
    end

    def initialize(@srid, @x, @y, @z)
    end
  end

  struct Polygon2D < Geography
    getter sections : Array(Array(Point2D))

    def self.from_ewkb(io, endian) : self
      srid = endian.decode(UInt32, io)

      sections = Array(Array(Point2D)).new(endian.decode(UInt32, io)) do
        Array(Point2D).new(endian.decode(UInt32, io)) do
          Point2D.new(
            x: endian.decode(Float64, io),
            y: endian.decode(Float64, io),
            srid: srid,
          )
        end
      end

      new(sections)
    end

    def initialize(@sections)
    end
  end

  class Error < ::Exception
  end

  class DecodingError < Error
  end

  module Decoders
    struct GeographyDecoder
      include PG::Decoders::Decoder

      def_oids [
        17056,
      ]

      def decode(io, bytesize, oid)
        endian = case endian_byte = io.read_byte
                 when 0
                   IO::ByteFormat::BigEndian
                 when 1
                   IO::ByteFormat::LittleEndian
                 else
                   raise DecodingError.new("Invalid endian byte marker: #{endian_byte.inspect}")
                 end

        Geography.from_ewkb(io, endian)
      end

      def type
        Geography
      end

      PG::Decoders.register_decoder new
    end
  end
end
