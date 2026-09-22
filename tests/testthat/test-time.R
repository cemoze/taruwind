test_that("UTC dates retain inclusive hourly boundaries", {
  p<-.taruwind_resolve_period(period=c("2020-01-01","2020-01-01"))
  expect_equal(as.numeric(difftime(p$end,p$start,units="hours")),23)
  expect_error(.taruwind_resolve_period(start="2020-01-01",period=c("2020-01-01","2020-01-01")),"combined")
  expect_error(.taruwind_period("2020-01-01 00:15:00","2020-01-01 01:00:00"),"whole hours")
})

test_that("local timestamps do not change UTC instants", {
  skip_if_not_installed("lutz")
  sites<-.taruwind_sites(lon=29,lat=41)
  x<-data.frame(site_id=sites$site_id,timestamp_utc=as.POSIXct("2020-01-01",tz="UTC"))
  y<-.taruwind_add_local_time(x,sites,TRUE)
  expect_identical(y$timestamp_utc,x$timestamp_utc)
  expect_equal(y$time_zone,"Europe/Istanbul")
  expect_equal(y$timestamp_local,"2020-01-01T03:00:00+0300")
})
