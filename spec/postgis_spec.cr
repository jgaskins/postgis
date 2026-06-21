require "./spec_helper"

require "../src/postgis"

TEST_DB.exec "CREATE EXTENSION IF NOT EXISTS postgis"

describe PostGIS do
  it "decodes 2D points" do
    expect_decode "SELECT 'point(1 2)'::geography", PostGIS::Point2D.new(
      x: 1.0,
      y: 2.0,
    )

    # TODO: How do we test empty points?
    # expect_decode "SELECT 'point empty'::geography", PostGIS::Point2D.new(
    #   x: Float64::NAN,
    #   y: Float64::NAN,
    # )
  end

  it "decodes 3D points" do
    expect_decode "SELECT 'point(1 2 3)'::geography", PostGIS::Point3D.new(
      srid: 4326_u32,
      x: 1.0,
      y: 2.0,
      z: 3.0,
    )
  end

  it "decodes polygons" do
    expect_decode "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geography", PostGIS::Polygon2D.new([
      [
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
      ],
    ])
    # expect_decode "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geography", 0 # PostGIS::Circle.new()
  end

  it "decodes 3D polygons" do
    expect_decode "SELECT 'polygon((1 2 3, 4 5 6, 7 8 9, 1 2 3))'::geography", PostGIS::Polygon3D.new([
      [
        PostGIS::Point3D.new(x: 1.0, y: 2.0, z: 3.0),
        PostGIS::Point3D.new(x: 4.0, y: 5.0, z: 6.0),
        PostGIS::Point3D.new(x: 7.0, y: 8.0, z: 9.0),
        PostGIS::Point3D.new(x: 1.0, y: 2.0, z: 3.0),
      ],
    ])
  end

  it "decodes polygons with holes" do
    expect_decode "SELECT 'polygon((0 0, 0 10, 10 10, 10 0, 0 0), (1 1, 1 2, 2 2, 2 1, 1 1))'::geography", PostGIS::Polygon2D.new([
      [
        PostGIS::Point2D.new(x: 0.0, y: 0.0),
        PostGIS::Point2D.new(x: 0.0, y: 10.0),
        PostGIS::Point2D.new(x: 10.0, y: 10.0),
        PostGIS::Point2D.new(x: 10.0, y: 0.0),
        PostGIS::Point2D.new(x: 0.0, y: 0.0),
      ],
      [
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 2.0),
        PostGIS::Point2D.new(x: 2.0, y: 1.0),
        PostGIS::Point2D.new(x: 1.0, y: 1.0),
      ],
    ])
  end

  it "decodes 2D linestrings" do
    expect_decode "SELECT 'linestring(1 2, 3 4, 5 6)'::geography", PostGIS::LineString2D.new([
      PostGIS::Point2D.new(x: 1.0, y: 2.0),
      PostGIS::Point2D.new(x: 3.0, y: 4.0),
      PostGIS::Point2D.new(x: 5.0, y: 6.0),
    ])
  end

  it "decodes 3D linestrings" do
    expect_decode "SELECT 'linestring(1 2 3, 4 5 6)'::geography", PostGIS::LineString3D.new([
      PostGIS::Point3D.new(x: 1.0, y: 2.0, z: 3.0),
      PostGIS::Point3D.new(x: 4.0, y: 5.0, z: 6.0),
    ])
  end

  it "decodes multipolygons" do
    sql = <<-SQL
      SELECT ST_Collect(
        'polygon((12 34, 23 45, 34 56, 12 34))'::geometry,
        'polygon((23 45, 34 56, 45 67, 23 45))'::geometry
      )::geography
      SQL

    expect_decode sql, PostGIS::MultiPolygon2D.new([
      PostGIS::Polygon2D.new([[
        PostGIS::Point2D.new(x: 12.0, y: 34.0),
        PostGIS::Point2D.new(x: 23.0, y: 45.0),
        PostGIS::Point2D.new(x: 34.0, y: 56.0),
        PostGIS::Point2D.new(x: 12.0, y: 34.0),
      ]]),
      PostGIS::Polygon2D.new([[
        PostGIS::Point2D.new(x: 23.0, y: 45.0),
        PostGIS::Point2D.new(x: 34.0, y: 56.0),
        PostGIS::Point2D.new(x: 45.0, y: 67.0),
        PostGIS::Point2D.new(x: 23.0, y: 45.0),
      ]]),
    ])
  end

  it "exposes a polygon's rings via the deprecated #sections method" do
    polygon = TEST_DB.query_one "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geography", as: PostGIS::Polygon2D

    polygon.sections.should eq polygon.rings
  end

  it "decodes as part of DB::Serializable" do
    sql = <<-SQL
      SELECT
        '123 Main St' street,
        'Baltimore' city,
        'MD' state,
        '21201' zip,
        'point(1 2)'::geography coordinates
    SQL
    address = TEST_DB.query_one sql, as: Address
    address.coordinates.should eq PostGIS::Point2D.new(
      x: 1.0,
      y: 2.0,
    )
  end
end

# `geometry` (planar) decodes from the same EWKB as `geography`, but carries no
# SRID, so the coordinates come back with `srid: 0`.
describe "PostGIS planar geometry" do
  it "decodes 2D points" do
    expect_decode "SELECT 'point(1 2)'::geometry", PostGIS::Point2D.new(
      x: 1.0,
      y: 2.0,
      srid: 0_u32,
    )
  end

  it "decodes 3D points" do
    expect_decode "SELECT 'point(1 2 3)'::geometry", PostGIS::Point3D.new(
      x: 1.0,
      y: 2.0,
      z: 3.0,
      srid: 0_u32,
    )
  end

  it "decodes 2D linestrings" do
    expect_decode "SELECT 'linestring(1 2, 3 4, 5 6)'::geometry", PostGIS::LineString2D.new([
      PostGIS::Point2D.new(x: 1.0, y: 2.0, srid: 0_u32),
      PostGIS::Point2D.new(x: 3.0, y: 4.0, srid: 0_u32),
      PostGIS::Point2D.new(x: 5.0, y: 6.0, srid: 0_u32),
    ])
  end

  it "decodes polygons" do
    expect_decode "SELECT 'polygon((1 1, 1 2, 2 2, 2 1, 1 1))'::geometry", PostGIS::Polygon2D.new([
      [
        PostGIS::Point2D.new(x: 1.0, y: 1.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 1.0, y: 2.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 2.0, y: 2.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 2.0, y: 1.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 1.0, y: 1.0, srid: 0_u32),
      ],
    ])
  end

  it "decodes multipolygons" do
    sql = <<-SQL
      SELECT ST_Collect(
        'polygon((12 34, 23 45, 34 56, 12 34))'::geometry,
        'polygon((23 45, 34 56, 45 67, 23 45))'::geometry
      )
      SQL

    expect_decode sql, PostGIS::MultiPolygon2D.new([
      PostGIS::Polygon2D.new([[
        PostGIS::Point2D.new(x: 12.0, y: 34.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 23.0, y: 45.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 34.0, y: 56.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 12.0, y: 34.0, srid: 0_u32),
      ]]),
      PostGIS::Polygon2D.new([[
        PostGIS::Point2D.new(x: 23.0, y: 45.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 34.0, y: 56.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 45.0, y: 67.0, srid: 0_u32),
        PostGIS::Point2D.new(x: 23.0, y: 45.0, srid: 0_u32),
      ]]),
    ])
  end

  it "decodes as part of DB::Serializable" do
    location = TEST_DB.query_one "SELECT 'point(1 2)'::geometry coordinates", as: Location
    location.coordinates.should eq PostGIS::Point2D.new(x: 1.0, y: 2.0, srid: 0_u32)
  end
end

private def expect_decode(query, as value : T) forall T
  TEST_DB
    .query_one(query, as: T)
    .should eq(value)
end

struct Address
  include DB::Serializable

  getter street : String
  getter city : String
  getter state : String
  getter zip : String
  getter coordinates : PostGIS::Point2D

  def initialize(@street, @city, @state, @zip, @coordinates)
  end
end

struct Location
  include DB::Serializable

  getter coordinates : PostGIS::Point2D

  def initialize(@coordinates)
  end
end
