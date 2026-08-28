import numpy as np


# activation function
def sigmoid(x):
	return 1 / (1 + np.exp(-x))


def softmax(x):
	# Convert the three output scores into probabilities that sum to 1.
	exp_x = np.exp(x - np.max(x, axis=1, keepdims=True))
	return exp_x / np.sum(exp_x, axis=1, keepdims=True)

# Creating the Feed forward neural network
def f_forward(x, w1, b1, w2, b2):
	# Save the hidden and output activations for backpropagation.
	z1 = x @ w1 + b1
	a1 = sigmoid(z1)
	z2 = a1 @ w2 + b2
	a2 = softmax(z2)
	return a1, a2

# initializing the weights randomly
def generate_wt(x, y):
	return np.random.randn(x, y) * np.sqrt(1 / x)

#loss function
def loss(out, Y):
	# Cross-entropy loss for a multi-class classification problem.
	out = np.clip(out, 1e-12, 1.0)
	return -np.mean(np.sum(Y * np.log(out), axis=1))

# Back propagation
def back_prop(x, y, a1, a2, w1, b1, w2, b2, alpha):
	# a1 and a2 came from f_forward(), so no second forward pass is needed.
	batch_size = len(x)
	d2 = (a2 - y) / batch_size
	d1 = (d2 @ w2.T) * a1 * (1 - a1)

	# Calculate gradients.
	w2_gradient = a1.T @ d2
	b2_gradient = np.sum(d2, axis=0, keepdims=True)
	w1_gradient = x.T @ d1
	b1_gradient = np.sum(d1, axis=0, keepdims=True)

	# Update weights and biases.
	w1 -= alpha * w1_gradient
	b1 -= alpha * b1_gradient
	w2 -= alpha * w2_gradient
	b2 -= alpha * b2_gradient

	return w1, b1, w2, b2


def train(x, y, w1, b1, w2, b2, alpha=0.01, epochs=10):
	accuracies = []
	losses = []

	for epoch in range(epochs):
		# Exactly one forward pass per epoch.
		a1, output = f_forward(x, w1, b1, w2, b2)
		current_loss = loss(output, y)
		accuracy = np.mean(np.argmax(output, axis=1) == np.argmax(y, axis=1))

		w1, b1, w2, b2 = back_prop(
			x, y, a1, output, w1, b1, w2, b2, alpha
		)

		losses.append(current_loss)
		accuracies.append(accuracy * 100)
		if epoch % 100 == 0 or epoch == epochs - 1:
			print(f"Epoch {epoch + 1}: loss={current_loss:.4f}, accuracy={accuracy:.1%}")

	return accuracies, losses, w1, b1, w2, b2



# Creating data set

# A
a =[0, 0, 1, 1, 0, 0,
   0, 1, 0, 0, 1, 0,
   1, 1, 1, 1, 1, 1,
   1, 0, 0, 0, 0, 1,
   1, 0, 0, 0, 0, 1]
# B
b =[0, 1, 1, 1, 1, 0,
   0, 1, 0, 0, 1, 0,
   0, 1, 1, 1, 1, 0,
   0, 1, 0, 0, 1, 0,
   0, 1, 1, 1, 1, 0]
# C
c =[0, 1, 1, 1, 1, 0,
   0, 1, 0, 0, 0, 0,
   0, 1, 0, 0, 0, 0,
   0, 1, 0, 0, 0, 0,
   0, 1, 1, 1, 1, 0]

# Creating labels
y =[[1, 0, 0],
   [0, 1, 0],
   [0, 0, 1]]

# converting data and labels into numpy array
x = np.array([a, b, c])
y = np.array(y)

# Initialize parameters once, before training.
np.random.seed(1)
w1 = generate_wt(30, 5)
b1 = np.zeros((1, 5))
w2 = generate_wt(5, 3)
b2 = np.zeros((1, 3))

accuracies, losses, w1, b1, w2, b2 = train(
	x, y, w1, b1, w2, b2, alpha=0.5, epochs=1000
)

# Use the trained network to make final predictions.
_, predictions = f_forward(x, w1, b1, w2, b2)
print("\nFinal probabilities:\n", predictions)
print("Predicted classes:", np.argmax(predictions, axis=1))
