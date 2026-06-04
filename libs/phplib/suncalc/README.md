SunCalc PHP
===========

SunCalc is a tiny PHP library for calculating sun position,
sunlight phases (times for sunrise, sunset, dusk, etc.),
moon position and lunar phase for the given location and time,
based on the JavaScript library created by [Vladimir Agafonkin](http://agafonkin.com/en) ([@mourner](https://github.com/mourner)).

Most calculations are based on the formulas given in the excellent Astronomy Answers articles
about [position of the sun](http://aa.quae.nl/en/reken/zonpositie.html)
and [the planets](http://aa.quae.nl/en/reken/hemelpositie.html).
You can read about different twilight phases calculated by SunCalc
in the [Twilight article on Wikipedia](http://en.wikipedia.org/wiki/Twilight).


## Usage example

```php
// initialise library class with date and coordinates today's sunlight times for Paris
$sc = new AurorasLive\SunCalc(new DateTime(), 48.85, 2.35);

// format sunrise time from the DateTime object
$sunTimes = $sc->getSunTimes();
$sunriseStr = $sunTimes['sunrise']->format('H:i');

// get position of the sun (azimuth and altitude) at today's sunrise
$sunrisePos = $sc->getPosition($sunTimes['sunrise']);

// get sunrise azimuth in degrees
$sunriseAzimuth = $sunrisePos->azimuth * 180 / M_PI;
```



## Reference

### Sunlight times

```php
AurorasLive\SunCalc :: getSunTimes()
```

Returns an array with the following indexes (each is a `DateTime` object):

| Property        | Description                                                              |
| --------------- | ------------------------------------------------------------------------ |
| `sunrise`       | sunrise (top edge of the sun appears on the horizon)                     |
| `sunriseEnd`    | sunrise ends (bottom edge of the sun touches the horizon)                |
| `goldenHourEnd` | morning golden hour (soft light, best time for photography) ends         |
| `solarNoon`     | solar noon (sun is in the highest position)                              |
| `goldenHour`    | evening golden hour starts                                               |
| `sunsetStart`   | sunset starts (bottom edge of the sun touches the horizon)               |
| `sunset`        | sunset (sun disappears below the horizon, evening civil twilight starts) |
| `dusk`          | dusk (evening nautical twilight starts)                                  |
| `nauticalDusk`  | nautical dusk (evening astronomical twilight starts)                     |
| `night`         | night starts (dark enough for astronomical observations)                 |
| `nadir`         | nadir (darkest moment of the night, sun is in the lowest position)       |
| `nightEnd`      | night ends (morning astronomical twilight starts)                        |
| `nauticalDawn`  | nautical dawn (morning nautical twilight starts)                         |
| `dawn`          | dawn (morning nautical twilight ends, morning civil twilight starts)     |

`SunCalc::times` property contains all currently defined times.


### Sun position

```php
AurorasLive\SunCalc :: getSunPosition(/*DateTime*/ $timeAndDate)
```

Returns an object with the following properties:

 * `altitude`: sun altitude above the horizon in radians,
 e.g. `0` at the horizon and `PI/2` at the zenith (straight over your head)
 * `azimuth`: sun azimuth in radians (direction along the horizon, measured from south to west),
 e.g. `0` is south and `M_PI * 3/4` is northwest


### Moon position

```php
AurorasLive\SunCalc :: getMoonPosition(/*DateTime*/ $timeAndDate)
```

Returns an object with the following properties:

 * `altitude`: moon altitude above the horizon in radians
 * `azimuth`: moon azimuth in radians
 * `distance`: distance to moon in kilometers


### Moon illumination

```php
AurorasLive\SunCalc :: getMoonIllumination()
```

Returns an array with the following properties:

 * `fraction`: illuminated fraction of the moon; varies from `0.0` (new moon) to `1.0` (full moon)
 * `phase`: moon phase; varies from `0.0` to `1.0`, described below
 * `angle`: midpoint angle in radians of the illuminated limb of the moon reckoned eastward from the north point of the disk;
 the moon is waxing if the angle is negative, and waning if positive

Moon phase value should be interpreted like this:

| Phase | Name            |
| -----:| --------------- |
| 0     | New Moon        |
|       | Waxing Crescent |
| 0.25  | First Quarter   |
|       | Waxing Gibbous  |
| 0.5   | Full Moon       |
|       | Waning Gibbous  |
| 0.75  | Last Quarter    |
|       | Waning Crescent |

### Moon rise and set times

```php
AurorasLive\SunCalc :: getMoonTimes($inUTC)
```

Returns an object with the following indexes:

 * `rise`: moonrise time as `DateTime`
 * `set`: moonset time as `DateTime`
 * `alwaysUp`: `true` if the moon never rises/sets and is always _above_ the horizon during the day
 * `alwaysDown`: `true` if the moon is always _below_ the horizon

By default, it will search for moon rise and set during local user's day (from 0 to 24 hours).
If `$inUTC` is set to true, it will instead search the specified date from 0 to 24 UTC hours.

## Changelog

#### 0.0.2 &mdash; 21 Aug, 2018

- Make this into a class and add a composer.json file to allow use with things like Laravel

#### 0.0.1 &mdash; 29 Jul, 2017

- Preserve original timezone when passing in dates

#### 0.0.0 &mdash; 30 Dec, 2015

- First commit.
