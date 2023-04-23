using DynamicExpressions, BenchmarkTools, Random

const v_PACKAGE_VERSION = try
    VersionNumber(PACKAGE_VERSION)
catch
    VersionNumber("v0.0.0")
end

const SUITE = BenchmarkGroup()

function benchmark_evaluation()
    suite = BenchmarkGroup()
    operators = OperatorEnum(;
        binary_operators=[+, -, /, *], unary_operators=[cos, exp], enable_autodiff=true
    )
    simple_tree = Node(
        2,
        Node(
            1,
            Node(
                3,
                Node(1, Node(; val=1.0f0), Node(; feature=2)),
                Node(2, Node(; val=-1.0f0)),
            ),
            Node(1, Node(; feature=3), Node(; feature=4)),
        ),
        Node(
            4,
            Node(
                3,
                Node(1, Node(; val=1.0f0), Node(; feature=2)),
                Node(2, Node(; val=-1.0f0)),
            ),
            Node(1, Node(; feature=3), Node(; feature=4)),
        ),
    )
    for T in (ComplexF32, ComplexF64, Float32, Float64)
        if !(T <: Real) && v_PACKAGE_VERSION < v"0.5.0" && v_PACKAGE_VERSION != v"0.0.0"
            continue
        end
        suite[T] = BenchmarkGroup()

        evals = 10
        samples = 1_000
        n = 1_000

        #! format: off
        for turbo in (false, true)
            if turbo && !(T in (Float32, Float64))
                continue
            end
            extra_key = turbo ? "_turbo" : ""
            suite[T]["evaluation$(extra_key)"] = @benchmarkable(
                eval_tree_array(tree, X, $operators; turbo=$turbo),
                evals=evals,
                samples=samples,
                seconds=5.0,
                setup=(
                    X=randn(MersenneTwister(0), $T, 5, $n);
                    tree=convert(Node{$T}, copy_node($simple_tree))
                )
            )
            if T <: Real
                suite[T]["derivative$(extra_key)"] = @benchmarkable(
                    eval_grad_tree_array(tree, X, $operators; variable=true, turbo=$turbo),
                    evals=evals,
                    samples=samples,
                    seconds=5.0,
                    setup=(
                        X=randn(MersenneTwister(0), $T, 5, $n);
                        tree=convert(Node{$T}, copy_node($simple_tree))
                    )
                )
            end
        end
        #! format: on
    end
end

SUITE["OperatorEnum"] = benchmark_evaluation()
