require "pg"
require "db"

require "./version"

module PostGIS
  @[Flags]
  enum TypeFlags : UInt16
    Z    = 0x8000
    M    = 0x4000
    SRID = 0x2000
    BBOX = 0x1000
  end

  enum Kind : UInt16
    Point              = 1
    LineString         = 2
    Polygon            = 3
    MultiPoint         = 4
    MultiLineString    = 5
    MultiPolygon       = 6
    GeometryCollection = 7
  end

  def self.register_decoder(db : DB::Database)
    oids = [] of Int32

    if oid = db.query_one?("SELECT oid::int4 FROM pg_type WHERE typname = 'geography'", as: Int32)
      oids << oid
    else
      raise MissingExtension.new("No `geography` type available in Postgres. The `postgis` extension might not be installed.")
    end

    if oid = db.query_one?("SELECT oid::int4 FROM pg_type WHERE typname = 'geometry'", as: Int32)
      oids << oid
    else
      raise MissingExtension.new("No `geometry` type available in Postgres. The `postgis` extension might not be installed.")
    end

    ::PG::Decoders.register_decoder Decoder.new(oids)
  end

  # The common supertype for everything PostGIS hands us. `geometry` and
  # `geography` can decode from identical EWKB, so they share one
  # hierarchy.
  abstract struct Geometry
    # Reads a complete (E)WKB geometry, including its leading endian byte.
    private def self.from_ewkb(io : IO) : Geometry
      endian = read_endian(io)
      type = io.read_bytes(UInt32, endian)
      flags = TypeFlags.new((type >> 16).to_u16)
      srid = flags.srid? ? io.read_bytes(UInt32, endian) : 0_u32

      case Kind.new((type & 0xffff).to_u16)
      in .point?
        flags.z? ? Point3D.read_body(io, endian, srid) : Point2D.read_body(io, endian, srid)
      in .line_string?
        flags.z? ? read_linestring(io, endian, srid, Point3D) : read_linestring(io, endian, srid, Point2D)
      in .polygon?
        flags.z? ? read_polygon(io, endian, srid, Point3D) : read_polygon(io, endian, srid, Point2D)
      in .multi_polygon?
        flags.z? ? read_multi_polygon(io, endian, srid, Point3D) : read_multi_polygon(io, endian, srid, Point2D)
      end
    end

    private def self.read_endian(io : IO) : IO::ByteFormat
      case endian_byte = io.read_byte
      when 0
        IO::ByteFormat::BigEndian
      when 1
        IO::ByteFormat::LittleEndian
      else
        raise DecodingError.new("Invalid endian byte marker: #{endian_byte.inspect}")
      end
    end

    protected def self.read_linestring(io, endian, srid, point : P.class) : LineString(P) forall P
      LineString(P).new(Array(P).new(io.read_bytes(UInt32, endian)) {
        P.read_body(io, endian, srid)
      })
    end

    protected def self.read_polygon(io, endian, srid, point : P.class) : Polygon(P) forall P
      Polygon(P).new(Array(Array(P)).new(io.read_bytes(UInt32, endian)) {
        Array(P).new(io.read_bytes(UInt32, endian)) { P.read_body(io, endian, srid) }
      })
    end

    protected def self.read_multi_polygon(io, endian, srid, point : P.class) : MultiPolygon(P) forall P
      MultiPolygon(P).new(Array(Polygon(P)).new(io.read_bytes(UInt32, endian)) {
        member_endian = read_endian(io)
        io.read_bytes(UInt32, member_endian) # member type code
        read_polygon(io, member_endian, srid, point)
      })
    end
  end

  # A `Point2D` represents a PostGIS `POINT` value on a 2-dimensional plane. The
  # `srid` may be set for `geography` values.
  struct Point2D < Geometry
    getter x : Float64
    getter y : Float64
    getter srid : UInt32

    def self.read_body(io, endian, srid) : self
      new(
        x: io.read_bytes(Float64, endian),
        y: io.read_bytes(Float64, endian),
        srid: srid,
      )
    end

    def initialize(@x, @y, @srid = 4326_u32)
    end
  end

  # A `Point3D` represents a PostGIS `POINT` value in 3-dimensional space. The
  # `srid` may be set for `geography` values.
  struct Point3D < Geometry
    getter x : Float64
    getter y : Float64
    getter z : Float64
    getter srid : UInt32

    def self.read_body(io, endian, srid) : self
      new(
        x: io.read_bytes(Float64, endian),
        y: io.read_bytes(Float64, endian),
        z: io.read_bytes(Float64, endian),
        srid: srid,
      )
    end

    def initialize(@x, @y, @z, @srid = 4326_u32)
    end
  end

  # An ordered list of points.
  struct LineString(Point) < Geometry
    getter points : Array(Point)

    def initialize(@points)
    end
  end

  # Rings of points: the first is the exterior ring, the rest are holes. All
  # polygons must be closed (the first point is equal to the last). For an
  # unclosed version, use `LineString`.
  struct Polygon(Point) < Geometry
    getter rings : Array(Array(Point))

    def initialize(@rings)
    end

    @[Deprecated("Use `#rings` instead.")]
    def sections : Array(Array(Point))
      rings
    end
  end

  # A collection of polygons. A MultiPolygon's members are always polygons, so
  # the only thing that varies is the point type.
  struct MultiPolygon(Point) < Geometry
    getter polygons : Array(Polygon(Point))

    def initialize(@polygons)
    end
  end

  # `geography` and `geometry` are different types in the PostGIS extension, but
  # they have an identical interface on the client side.
  alias Geography = Geometry

  alias LineString2D = LineString(Point2D)
  alias LineString3D = LineString(Point3D)
  alias Polygon2D = Polygon(Point2D)
  alias Polygon3D = Polygon(Point3D)
  alias MultiPolygon2D = MultiPolygon(Point2D)
  alias MultiPolygon3D = MultiPolygon(Point3D)

  class Error < ::Exception
  end

  class DecodingError < Error
  end

  class MissingExtension < Error
  end

  struct Decoder
    include PG::Decoders::Decoder

    getter oids : Array(Int32)

    def initialize(@oids)
    end

    def decode(io, bytesize, oid)
      Geometry.from_ewkb(io)
    end

    def type
      Geometry
    end
  end
end
