#!/usr/bin/python3 -B

import unittest
from unittest import mock

import numpy as np
import pandas as pd

import task


def data_gen_helper(uri, word, tfidf, feed_url):
    return {
        "uri": uri,
        "word": word,
        "tfidf": tfidf,
        "feedUrl": feed_url,
    }


class TestTfidfBqTable(unittest.TestCase):

    @mock.patch("task.bigquery")
    def test_unique_words(self, mock_bigquery):
        sut = task.TfidfBqTable()
        sut.data = [
            data_gen_helper("aaa", "apple", "bbb", "ccc"),
            data_gen_helper("aaa", "banana", "bbb", "ccc"),
            data_gen_helper("aaa", "diamond", "bbb", "ccc"),
            data_gen_helper("aaa", "cola", "bbb", "ccc"),
            data_gen_helper("aaa", "banana", "bbb", "ccc"),
        ]

        assert sut.unique_words() == [
            "apple",
            "banana",
            "cola",
            "diamond",
        ]

    @mock.patch("task.bigquery")
    def test_uri_to_word_and_tfidf_list(self, mock_bigquery):
        sut = task.TfidfBqTable()
        sut.data = [
            data_gen_helper("aaa.com", "apple", 0., "ccc"),
            data_gen_helper("ddd.com", "banana", 1., "ccc"),
            data_gen_helper("eee.com", "diamond", 2., "ccc"),
            data_gen_helper("bbb.com", "cola", 3., "ccc"),
            data_gen_helper("fff.com", "banana", 4., "ccc"),
            data_gen_helper("ddd.com", "forest", 5., "ccc"),
        ]

        assert sut.uri_to_word_and_tfidf_list() == {
            "aaa.com": [("apple", 0.)],
            "ddd.com": [("banana", 1.), ("forest", 5.)],
            "eee.com": [("diamond", 2.)],
            "bbb.com": [("cola", 3.)],
            "fff.com": [("banana", 4.)],
        }

    @mock.patch("task.bigquery")
    def test_uris(self, mock_bigquery):
        sut = task.TfidfBqTable()
        sut.data = [
            data_gen_helper("aaa.com", "apple", "bbb", "ccc"),
            data_gen_helper("ddd.com", "banana", "bbb", "ccc"),
            data_gen_helper("eee.com", "diamond", "bbb", "ccc"),
            data_gen_helper("bbb.com", "cola", "bbb", "ccc"),
            data_gen_helper("fff.com", "banana", "bbb", "ccc"),
        ]

        assert sut.uris() == [
            "aaa.com",
            "bbb.com",
            "ddd.com",
            "eee.com",
            "fff.com",
        ]

    @mock.patch("task.bigquery")
    def test_uri_to_feedurl_list(self, mock_bigquery):
        sut = task.TfidfBqTable()
        sut.data = [
            data_gen_helper("aaa.com", "apple", "bbb", "aaa.rss"),
            data_gen_helper("ddd.com", "banana", "bbb", "ddd.rss"),
            data_gen_helper("eee.com", "diamond", "bbb", "eee.rss"),
            data_gen_helper("bbb.com", "cola", "bbb", "bbb.rss"),
            data_gen_helper("fff.com", "banana", "bbb", "fff.rss"),
            data_gen_helper("ddd.com", "banana", "bbb", "ccc.rss"),
        ]

        assert sut.uri_to_feedurl_list() == {
            "aaa.com": ["aaa.rss"],
            "ddd.com": ["ddd.rss", "ccc.rss"],
            "eee.com": ["eee.rss"],
            "bbb.com": ["bbb.rss"],
            "fff.com": ["fff.rss"],
        }

    @mock.patch("task.bigquery")
    def test_read_as_dataframe(self, mock_bigquery):
        sut = task.TfidfBqTable()
        sut.data = [
            data_gen_helper("aaa.com", "apple", 0., "ccc"),
            data_gen_helper("ddd.com", "banana", 1., "ccc"),
            data_gen_helper("eee.com", "diamond", 2., "ccc"),
            data_gen_helper("bbb.com", "cola", 3., "ccc"),
            data_gen_helper("fff.com", "banana", 4., "ccc"),
            data_gen_helper("ddd.com", "forest", 5., "ccc"),
        ]

        out = sut.read_as_dataframe()
        assert all(out.index == [
            "aaa.com",
            "bbb.com",
            "ddd.com",
            "eee.com",
            "fff.com",
        ])
        assert all(out.columns == [
            "apple",
            "banana",
            "cola",
            "diamond",
            "forest",
        ])
        np.testing.assert_equal(
            out.to_numpy(),
            np.array([
                [0., 0., 0., 0., 0.],
                [0., 0., 3., 0., 0.],
                [0., 1., 0., 0., 5.],
                [0., 0., 0., 2., 0.],
                [0., 4., 0., 0., 0.],
            ]))


class TestKde(unittest.TestCase):

    def test_integration(self):
        input_data = np.random.randn(20, 100)
        task.Kde(input_data).score_samples(
            task.Kde(input_data).grid_search_bandwidth())


class TestTrendScoreFirestore(unittest.TestCase):

    @mock.patch("task.firestore")
    def test_write_exist(self, mock_firestore):
        sut = task.TrendScoreFirestore(
            pd.DataFrame(
                np.array([
                    ["http://aaa/bbb.com", "aaa/bbb/ccc.rss", 1.],
                ]),
                columns=["uri", "feed_url", "trend_score"],
            ))

        mock_feed_url_collection = mock_firestore.Client.return_value.collection.return_value.document.return_value.collection
        mock_uri_document = mock_feed_url_collection.return_value.document
        mock_uri_ref = mock_uri_document.return_value
        mock_uri_ref.get.return_value.exists = True

        sut.write()
        mock_feed_url_collection.assert_called_once_with("aaa_bbb_ccc.rss")
        mock_uri_document.assert_called_once_with("http:__aaa_bbb.com")
        mock_uri_ref.set.assert_called()

    @mock.patch("task.firestore")
    def test_write_non_exist(self, mock_firestore):
        sut = task.TrendScoreFirestore(
            pd.DataFrame(
                np.array([
                    ["http://aaa/bbb.com", "aaa/bbb/ccc.rss", 1.],
                ]),
                columns=["uri", "feed_url", "trend_score"],
            ))

        mock_feed_url_collection = mock_firestore.Client.return_value.collection.return_value.document.return_value.collection
        mock_uri_document = mock_feed_url_collection.return_value.document
        mock_uri_ref = mock_uri_document.return_value
        mock_uri_ref.get.return_value.exists = False

        sut.write()

        mock_feed_url_collection.assert_called_once_with("aaa_bbb_ccc.rss")
        mock_uri_document.assert_called_once_with("http:__aaa_bbb.com")
        mock_uri_ref.set.assert_not_called()


if __name__ == "__main__":
    unittest.main()
