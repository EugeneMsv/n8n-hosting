Task
Analyze Amazon order emails and calculate total spending
Required Tools

Date & Time - Get current date (include month) and first day of current month
Secondary Gmail account - Search and retrieve emails

Search Criteria

Sender: auto-confirm@amazon.com
Subject: Starts with "Ordered: "
Date range: First day of current month to today (format: YYYY-MM-DD)
Limit: 100 emails

Processing

Extract order block(use exact pattern, no changes): Total\s*\$?(\d+(?:\.\d{1,2})?)\s*(?:USD)?
Captured block contains: total per order
Parse block for all details
One total per email

Return Format

Month name (e.g., "October 2025")
Grand total with currency
(Pretty print it for Telegram)
List of orders showing: order total (USD), individual prices
The hard stop for 3072 symbols in the response
Never shorten prices
If no orders: $0.00 USD
