FROM ryshe/terraria:latest

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Optional runtime args are handled by /start.sh via env vars such as
# WORLD_FILENAME, WORLD_SIZE, and WORLD_DIFFICULTY.

ENTRYPOINT ["/start.sh"]
