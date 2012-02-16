-- phpMyAdmin SQL Dump
-- version 3.3.2deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: May 24, 2011 at 03:19 PM
-- Server version: 5.1.41
-- PHP Version: 5.3.2-1ubuntu4.9

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `comet`
--

-- --------------------------------------------------------

--
-- Table structure for table `comet_g2t`
--

CREATE TABLE IF NOT EXISTS `comet_g2t` (
  `g` mediumint(8) unsigned NOT NULL,
  `t` mediumint(8) unsigned NOT NULL,
  UNIQUE KEY `gt` (`g`,`t`),
  KEY `tg` (`t`,`g`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;

-- --------------------------------------------------------

--
-- Table structure for table `comet_id2val`
--

CREATE TABLE IF NOT EXISTS `comet_id2val` (
  `id` mediumint(8) unsigned NOT NULL,
  `misc` tinyint(1) NOT NULL DEFAULT '0',
  `val` text COLLATE utf8_unicode_ci NOT NULL,
  `val_type` tinyint(1) NOT NULL DEFAULT '0',
  UNIQUE KEY `id` (`id`,`val_type`),
  KEY `v` (`val`(64))
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;

-- --------------------------------------------------------

--
-- Table structure for table `comet_o2val`
--

CREATE TABLE IF NOT EXISTS `comet_o2val` (
  `id` mediumint(8) unsigned NOT NULL,
  `misc` tinyint(1) NOT NULL DEFAULT '0',
  `val_hash` char(32) COLLATE utf8_unicode_ci NOT NULL,
  `val` text COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `id` (`id`),
  KEY `vh` (`val_hash`),
  KEY `v` (`val`(64))
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;

-- --------------------------------------------------------

--
-- Table structure for table `comet_s2val`
--

CREATE TABLE IF NOT EXISTS `comet_s2val` (
  `id` mediumint(8) unsigned NOT NULL,
  `misc` tinyint(1) NOT NULL DEFAULT '0',
  `val_hash` char(32) COLLATE utf8_unicode_ci NOT NULL,
  `val` text COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `id` (`id`),
  KEY `vh` (`val_hash`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;

-- --------------------------------------------------------

--
-- Table structure for table `comet_setting`
--

CREATE TABLE IF NOT EXISTS `comet_setting` (
  `k` char(32) COLLATE utf8_unicode_ci NOT NULL,
  `val` text COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `k` (`k`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;

-- --------------------------------------------------------

--
-- Table structure for table `comet_triple`
--

CREATE TABLE IF NOT EXISTS `comet_triple` (
  `t` mediumint(8) unsigned NOT NULL,
  `s` mediumint(8) unsigned NOT NULL,
  `p` mediumint(8) unsigned NOT NULL,
  `o` mediumint(8) unsigned NOT NULL,
  `o_lang_dt` mediumint(8) unsigned NOT NULL,
  `o_comp` char(35) COLLATE utf8_unicode_ci NOT NULL,
  `s_type` tinyint(1) NOT NULL DEFAULT '0',
  `o_type` tinyint(1) NOT NULL DEFAULT '0',
  `misc` tinyint(1) NOT NULL DEFAULT '0',
  UNIQUE KEY `t` (`t`),
  KEY `sp` (`s`,`p`),
  KEY `os` (`o`,`s`),
  KEY `po` (`p`,`o`),
  KEY `misc` (`misc`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci DELAY_KEY_WRITE=1;
