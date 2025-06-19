import datetime
import enum
import itertools
import re
from xml.sax import saxutils
from os import path

import bs4

from beancount.core.number import D
from beancount.core import amount
from beancount.core import data
from beancount.ingest import importer
from beancount.ingest.importers import ofx 

class TaggedNarrationOfxImporter(ofx.Importer):
    """
    OFX importer that adds extra postings to Beancount transactions with matching narration

    The importer takes in a map narration_to_account that tags accounts with
    specific narration strings to accounts. For example, a narration string like
    'Taco Bell' might be mapped to account 'Expenses:Food'.

    Note that narration strings must be _exact_ matches to the keys in the 
    narration_to_account map. A more flexible implementation would allow regexes 
    instead of just exact matches, but:
    - it will force linear search of the dictionary to find matching regex keys
    - have to ensure there is a single matching regex a time

    Tested with Beancount 2.6.3.
    """

    def __init__(self, narration_to_account, acctid_regexp, account, basename=None, balance_type=ofx.BalanceType.DECLARED):
        super().__init__(acctid_regexp, account, basename, balance_type)
        self.narration_to_account = narration_to_account

    def extract(self, file, existing_entries=None):
        """Extract a list of partially complete transactions from the file."""
        soup = bs4.BeautifulSoup(file.contents(), "lxml")
        return self._extract(
            soup, file.name, self.acctid_regexp, self.account, self.FLAG, self.balance_type
        )

    def _extract(self, soup, filename, acctid_regexp, account, flag, balance_type):
        """
        Mostly a copy of extract in https://github.com/beancount/beancount/blob/v2/beancount/ingest/importers/ofx.py
        Replaces ofx.build_transaction with a new function (defined above)

        Extract transactions from an OFX file.

        Args:
          soup: A BeautifulSoup root node.
          acctid_regexp: A regular expression string matching the account we're interested in.
          account: An account string onto which to post the amounts found in the file.
          flag: A single-character string.
          balance_type: An enum of type BalanceType.
        Returns:
          A sorted list of entries.
        """
        new_entries = []
        counter = itertools.count()
        for acctid, currency, transactions, balance in ofx.find_statement_transactions(soup):
            if not re.match(acctid_regexp, acctid):
                continue

            # Create Transaction directives.
            stmt_entries = []
            for stmttrn in transactions:
                entry = self.build_transaction(stmttrn, flag, account, currency)
                entry = entry._replace(meta=data.new_metadata(filename, next(counter)))
                stmt_entries.append(entry)
            stmt_entries = data.sorted(stmt_entries)
            new_entries.extend(stmt_entries)

            # Create a Balance directive.
            if balance and balance_type is not ofx.BalanceType.NONE:
                date, number = balance
                if balance_type is ofx.BalanceType.LAST and stmt_entries:
                    date = stmt_entries[-1].date

                # The Balance assertion occurs at the beginning of the date, so move
                # it to the following day.
                date += datetime.timedelta(days=1)

                meta = data.new_metadata(filename, next(counter))
                balance_entry = data.Balance(
                    meta, date, account, amount.Amount(number, currency), None, None
                )
                new_entries.append(balance_entry)

        return data.sorted(new_entries)

    def build_transaction(self, stmttrn, flag, account, currency):
        """
        Mostly a copy of build_transaction in https://github.com/beancount/beancount/blob/v2/beancount/ingest/importers/ofx.py
        Adds extra postings for certain transactions

        Build a single transaction.


        Args:
          stmttrn: A <STMTTRN> bs4.element.Tag.
          flag: A single-character string.
          account: An account string, the account to insert.
          currency: A currency string.
        Returns:
          A Transaction instance.
        """
        # Find the date.
        date = ofx.parse_ofx_time(ofx.find_child(stmttrn, "dtposted")).date()

        # There's no distinct payee.
        payee = None

        # Construct a description that represents all the text content in the node.
        name = ofx.find_child(stmttrn, "name", saxutils.unescape)
        memo = ofx.find_child(stmttrn, "memo", saxutils.unescape)

        # Remove memos duplicated from the name.
        if memo == name:
            memo = None

        # Add the transaction type to the description, unless it's not useful.
        trntype = ofx.find_child(stmttrn, "trntype", saxutils.unescape)
        if trntype in ("DEBIT", "CREDIT"):
            trntype = None

        narration = " / ".join(filter(None, [name, memo, trntype]))

        # Create a single posting for it; the user will have to manually categorize
        # the other side.
        number = ofx.find_child(stmttrn, "trnamt", D)
        units = amount.Amount(number, currency)

        postings = [data.Posting(account, units, None, None, None, None)]

        if narration in self.narration_to_account:
            postings.append(data.Posting(self.narration_to_account[narration], None, None, None, None, None))

        # Build the transaction with a single leg.
        fileloc = data.new_metadata("<build_transaction>", 0)
        return data.Transaction(
            fileloc, date, flag, payee, narration, data.EMPTY_SET, data.EMPTY_SET, postings
        )

