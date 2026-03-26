## Grand Prix ABM

Agent-based model build in NetLogo, to simulate the Silverstone F1 Grand Prix. The user can customise limited starting parameters for a single car-agent (or the entire grid using "dev mode" controls), but the pathfinding and "racing" logic is handled by the agent.
The car agents use "whiskers" to see the track on their initial lap, and set the found path as their "racing line", which is then randomly mutated in subsequent laps in an attempt to iteratively improve lap-times.
There are proxy-agents that contain and write the car-agent data (to avoid car-agent freezing/stuttering between laps), and also serve as a leaderboard [needs some work, doesn't properly account for lap time vs. lap completion].

Model needs the "silverstone_alt.png" file as input for the track.

More detailed user instructions can be accessed in the model with the corresponding button.
Further model details can be found in the ODD Protocol in the nlogo file.
Built in NetLogo 6.4